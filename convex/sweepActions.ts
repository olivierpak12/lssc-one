"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";
import { ethers } from "ethers";
import * as crypto from "crypto";
import { getProvider, withRetry } from "./lib/rpcHelpers";

export const processAutoSweep = action({
  args: { depositId: v.id("deposits") },
  handler: async (ctx, args): Promise<{ success: boolean; message?: string; error?: string }> => {
    console.log(`[Sweep] 🚀 Starting sweep for deposit: ${args.depositId}`);

    const deposit: any = await ctx.runQuery(api.deposits.getDeposit, { depositId: args.depositId });
    if (!deposit || (deposit.status !== "confirmed" && deposit.status !== "pending")) {
        console.log(`[Sweep] Skipping: Deposit ${args.depositId} is already ${deposit?.status}`);
        return { success: false, message: `Deposit is ${deposit?.status}` };
    }

    const walletData: any = await ctx.runQuery(api.wallets.getWallet, { userId: deposit.userId });
    const network: any = await ctx.runQuery(api.networks.getNetworkInfo, { chainId: deposit.chainId });
    if (!walletData || !network) return { success: false, message: "Missing wallet/network info" };

    const rpcUrl = process.env[network.rpcUrl] || process.env[(network as any).defaultRpc];
    const usdtAddress = deposit.tokenContract || process.env[(network as any).usdtContractEnv] || network.usdtContract;

    if (!rpcUrl || !usdtAddress) {
      console.error(`[Sweep] ❌ Configuration missing for ${network.name}`);
      return { success: false, message: "Missing RPC or USDT contract" };
    }

    const encryptionKey = process.env.ENCRYPTION_KEY;
    if (!encryptionKey) throw new Error("ENCRYPTION_KEY not set in Convex Dashboard");
    
    let decryptedKey: string;
    try {
        const iv = Buffer.from(walletData.iv, "hex");
        const decipher = crypto.createDecipheriv("aes-256-cbc", Buffer.from(encryptionKey, "utf-8"), iv);
        decryptedKey = decipher.update(walletData.encryptedPrivateKey, "hex", "utf8");
        decryptedKey += decipher.final("utf8");
        if (!decryptedKey.startsWith("0x")) decryptedKey = "0x" + decryptedKey;
    } catch (e) {
        console.error("[Sweep] ❌ Decryption failed. Check ENCRYPTION_KEY.");
        return { success: false, message: "Decryption error" };
    }

    const provider = getProvider(network);
    const userWallet = new ethers.Wallet(decryptedKey, provider);
    const hotWalletAddress = process.env.HOT_WALLET_ADDRESS;
    const gasFunderKey = process.env.GAS_FUNDER_PRIVATE_KEY;

    if (!hotWalletAddress || !gasFunderKey) {
        console.error("[Sweep] ❌ Admin credentials missing in Convex Settings.");
        return { success: false, message: "Admin setup incomplete" };
    }
    
    const gasFunder = new ethers.Wallet(gasFunderKey.startsWith("0x") ? gasFunderKey : "0x" + gasFunderKey, provider);
    const usdtContract = new ethers.Contract(
      usdtAddress,
      ["function transfer(address to, uint256 amount) public returns (bool)", "function balanceOf(address account) public view returns (uint256)"],
      userWallet
    );

    try {
      console.log(`[Sweep] 📡 Checking balance for ${userWallet.address} on ${network.name} (Contract: ${usdtAddress})`);
      
      let usdtBalance = await withRetry(
        () => usdtContract.balanceOf(userWallet.address),
        "balanceOf"
      );
      
      if (usdtBalance === 0n) {
          console.log("[Sweep] ⏳ Balance is 0. Waiting 5 seconds for node sync...");
          await new Promise(r => setTimeout(r, 5000));
          usdtBalance = await withRetry(
            () => usdtContract.balanceOf(userWallet.address),
            "balanceOf (resync)"
          );
      }

      console.log(`[Sweep] 💰 On-chain Balance: ${ethers.formatUnits(usdtBalance, 6)} USDT`);

      if (usdtBalance === 0n) {
          console.warn(`[Sweep] ❌ Wallet has 0 USDT on-chain. Cannot sweep.`);
          return { success: false, message: "No funds found on-chain" };
      }

      const feeData = await provider.getFeeData();
      const gasPrice = feeData.gasPrice ?? ethers.parseUnits("30", "gwei");
      const gasLimit = 80000n;
      const gasNeeded = gasPrice * gasLimit;
      const userNative = await provider.getBalance(userWallet.address);
      
      if (userNative < gasNeeded) {
        console.log(`[Sweep] ⛽ Funding gas...`);
        const fundTx = await withRetry(
          () => gasFunder.sendTransaction({ to: userWallet.address, value: gasNeeded * 2n }),
          "gasFunder.sendTransaction"
        );
        await withRetry(() => fundTx.wait(), "fundTx.wait");
      }

      console.log(`[Sweep] 🧹 Sweeping to ${hotWalletAddress}`);
      const sweepTx = await withRetry(
        () => usdtContract.transfer(hotWalletAddress, usdtBalance),
        "contract.transfer"
      );
      await withRetry(() => sweepTx.wait(), "sweepTx.wait");
      
      await ctx.runMutation(api.deposits.updateStatus, { depositId: deposit._id, status: "swept", sweepTxHash: sweepTx.hash });
      console.log(`[Sweep] ✅ SUCCESS: ${sweepTx.hash}`);
      return { success: true };
    } catch (error: any) {
      console.error("[Sweep] ❌ Failure:", error.message);
      return { success: false, error: error.message };
    }
  },
});

export const sweepAllConfirmed = action({
  args: {},
  handler: async (ctx): Promise<{ message: string }> => {
    // Explicitly bypass the stale type system for 'listAllConfirmed'
    const depositsApi: any = api.deposits;
    const confirmed = await ctx.runQuery(depositsApi.listAllConfirmed, {});
    
    let count = 0;
    for (const d of confirmed as any[]) {
      const res: any = await ctx.runAction(api.sweepActions.processAutoSweep, { depositId: d._id });
      if (res.success) count++;
    }
    return { message: `Swept ${count} deposits.` };
  },
});

/**
 * REPAIR: Resets any 'swept' deposits that failed (missing sweepTxHash) 
 * so they can be tried again.
 */
export const repairStuckDeposits = action({
  args: {},
  handler: async (ctx): Promise<{ message: string }> => {
    const depositsApi: any = api.deposits;
    const allDeposits = await ctx.runQuery(depositsApi.listDepositsRaw, {});
    let repaired = 0;
    for (const d of allDeposits as any[]) {
        if (d.status === "swept" && !d.sweepTxHash) {
            await ctx.runMutation(api.deposits.updateStatus, { 
                depositId: d._id, 
                status: "confirmed" 
            });
            repaired++;
        }
    }
    return { message: `Repaired ${repaired} stuck deposits. You can now run sweepAllConfirmed.` };
  },
});
