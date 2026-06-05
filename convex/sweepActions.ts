"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";
import { ethers } from "ethers";
import * as crypto from "crypto";
import { getProvider, withRetry, getGasFees, ChainGasFees } from "./lib/rpcHelpers";

// ─── Robust tx wait ──────────────────────────────────────────────────────────
// ethers v6 bug: tx.wait() hangs forever if a tx is replaced/dropped (#4875).
// We poll manually using getTransactionReceipt instead.

async function waitForReceipt(
  provider: ethers.JsonRpcProvider,
  txHash: string,
  timeoutMs: number = 180_000,
  pollIntervalMs: number = 3_000
): Promise<ethers.TransactionReceipt> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const receipt = await provider.getTransactionReceipt(txHash);
    if (receipt && receipt.status !== null) {
      if (receipt.status === 0) throw new Error(`Transaction reverted on-chain: ${txHash}`);
      return receipt;
    }
    await new Promise((r) => setTimeout(r, pollIntervalMs));
  }
  throw new Error(`Transaction not confirmed after ${timeoutMs / 1000}s — hash: ${txHash}`);
}

// ─── Cancel stuck nonces ─────────────────────────────────────────────────────
// Sends 0 native to self with high gas to replace any stuck pending txs.

async function cancelStuckNonces(
  wallet: ethers.Wallet,
  provider: ethers.JsonRpcProvider,
  fees: ChainGasFees
): Promise<void> {
  const confirmedNonce = await provider.getTransactionCount(wallet.address, "latest");
  const pendingNonce = await provider.getTransactionCount(wallet.address, "pending");

  if (pendingNonce <= confirmedNonce) {
    console.log(`[Nonce] ✅ No stuck nonces for ${wallet.address}`);
    return;
  }

  console.warn(`[Nonce] ⚠️ Found ${pendingNonce - confirmedNonce} stuck nonce(s) — cancelling...`);

  // 2x current gas guarantees replacement
  const cancelFees: ChainGasFees = fees.gasPrice
    ? { gasPrice: fees.gasPrice * 2n }
    : {
        maxFeePerGas: fees.maxFeePerGas! * 2n,
        maxPriorityFeePerGas: fees.maxPriorityFeePerGas! * 2n,
      };

  for (let nonce = confirmedNonce; nonce < pendingNonce; nonce++) {
    try {
      const tx = await wallet.sendTransaction({
        to: wallet.address,
        value: 0n,
        nonce,
        gasLimit: 21000n,
        ...cancelFees,
      });
      console.log(`[Nonce] 🧹 Cancelling nonce ${nonce}: ${tx.hash}`);
      await waitForReceipt(provider, tx.hash, 60_000);
      console.log(`[Nonce] ✅ Nonce ${nonce} cancelled`);
    } catch (err) {
      console.error(`[Nonce] ❌ Failed to cancel nonce ${nonce}: ${err}`);
    }
  }
}

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

    // Resolve the correct contract address based on which token was deposited.
    // Priority: deposit.tokenContract (explicit on-chain address) → env var override → network record.
    // deposit.token is "USDT" or "USDC" — never assume USDT.
    const tokenSymbol: string = (deposit.token ?? "USDT").toUpperCase();
    const tokenAddress: string | undefined =
      deposit.tokenContract ||
      (tokenSymbol === "USDC"
        ? process.env[(network as any).usdcContractEnv] || network.usdcContract
        : process.env[(network as any).usdtContractEnv] || network.usdtContract);

    if (!rpcUrl || !tokenAddress) {
      console.error(`[Sweep] ❌ Configuration missing for ${network.name} — no ${tokenSymbol} contract address found`);
      return { success: false, message: `Missing RPC or ${tokenSymbol} contract` };
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

    const gasFunder = new ethers.Wallet(
      gasFunderKey.startsWith("0x") ? gasFunderKey : "0x" + gasFunderKey,
      provider
    );

    const tokenContract = new ethers.Contract(
      tokenAddress,
      [
        "function transfer(address to, uint256 amount) public returns (bool)",
        "function balanceOf(address account) public view returns (uint256)",
      ],
      userWallet
    );

    try {
      console.log(`[Sweep] 📡 Checking ${tokenSymbol} balance for ${userWallet.address} on ${network.name} (Contract: ${tokenAddress})`);

      let tokenBalance = await withRetry(() => tokenContract.balanceOf(userWallet.address), "balanceOf");

      if (tokenBalance === 0n) {
        console.log("[Sweep] ⏳ Balance is 0. Waiting 5s for node sync...");
        await new Promise((r) => setTimeout(r, 5000));
        tokenBalance = await withRetry(() => tokenContract.balanceOf(userWallet.address), "balanceOf (resync)");
      }

      console.log(`[Sweep] 💰 On-chain Balance: ${ethers.formatUnits(tokenBalance, 6)} ${tokenSymbol}`);

      if (tokenBalance === 0n) {
        console.warn(`[Sweep] ❌ Wallet has 0 ${tokenSymbol} on-chain. Cannot sweep.`);
        return { success: false, message: `No ${tokenSymbol} found on-chain` };
      }

      // ─── Fetch correct gas fees for THIS chain ───────────────────────────
      // getGasFees() handles each chain correctly:
      //   Polygon (137) → Polygon gas station oracle, EIP-1559
      //   BSC (56/97)   → legacy gasPrice only (BSC doesn't support EIP-1559)
      //   Ethereum (1)  → standard EIP-1559 via provider.getFeeData()
      //   Others        → EIP-1559 with 30% buffer fallback
      const fees = await getGasFees(network.chainId, provider);

      const gasLimit = 80000n;
      // For cost estimate use maxFeePerGas (EIP-1559) or gasPrice (legacy)
      const gasPriceForEstimate = fees.maxFeePerGas ?? fees.gasPrice!;
      const gasNeeded = gasPriceForEstimate * gasLimit;
      const userNative = await provider.getBalance(userWallet.address);

      console.log(`[Sweep] ⛽ Gas needed: ${ethers.formatEther(gasNeeded)} ${network.symbol}, user has: ${ethers.formatEther(userNative)} ${network.symbol}`);

      // ─── Gas funding ──────────────────────────────────────────────────────
      if (userNative < gasNeeded) {
        const funderBalance = await provider.getBalance(gasFunder.address);
        console.log(`[Sweep] 🏦 Gas funder balance: ${ethers.formatEther(funderBalance)} ${network.symbol}`);

        if (funderBalance < gasNeeded * 2n) {
          console.error(`[Sweep] ❌ Gas funder insufficient. Has: ${ethers.formatEther(funderBalance)}, needs: ${ethers.formatEther(gasNeeded * 2n)}`);
          return { success: false, error: `Gas funder wallet has insufficient ${network.symbol}.` };
        }

        await cancelStuckNonces(gasFunder, provider, fees);

        const funderNonce = await provider.getTransactionCount(gasFunder.address, "latest");
        console.log(`[Sweep] ⛽ Funding gas (nonce: ${funderNonce})...`);

        const fundTx = await withRetry(
          () =>
            gasFunder.sendTransaction({
              to: userWallet.address,
              value: gasNeeded * 2n,
              gasLimit: 21000n,
              nonce: funderNonce,
              ...fees,
            }),
          "gasFunder.sendTransaction"
        );

        console.log(`[Sweep] ⛽ Fund tx sent: ${fundTx.hash} — polling for receipt...`);
        const fundReceipt = await waitForReceipt(provider, fundTx.hash, 180_000);
        console.log(`[Sweep] ⛽ Gas funded in block ${fundReceipt.blockNumber}`);
      } else {
        console.log(`[Sweep] ⛽ User wallet already has enough ${network.symbol}, skipping gas fund`);
      }

      // ─── Sweep ────────────────────────────────────────────────────────────
      console.log(`[Sweep] 🧹 Sweeping ${ethers.formatUnits(tokenBalance, 6)} ${tokenSymbol} to ${hotWalletAddress}`);

      await cancelStuckNonces(userWallet, provider, fees);

      const sweepNonce = await provider.getTransactionCount(userWallet.address, "latest");
      console.log(`[Sweep] 🧹 Sweep nonce: ${sweepNonce}`);

      const sweepTx = await withRetry(
        () =>
          tokenContract.transfer(hotWalletAddress, tokenBalance, {
            gasLimit,
            nonce: sweepNonce,
            ...fees,
          }),
        "contract.transfer"
      );

      console.log(`[Sweep] 🧹 Sweep tx sent: ${sweepTx.hash} — polling for receipt...`);
      const sweepReceipt = await waitForReceipt(provider, sweepTx.hash, 180_000);

      await ctx.runMutation(api.deposits.updateStatus, {
        depositId: deposit._id,
        status: "swept",
        sweepTxHash: sweepTx.hash,
      });

      console.log(`[Sweep] ✅ SUCCESS in block ${sweepReceipt.blockNumber}: ${sweepTx.hash}`);
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
          status: "confirmed",
        });
        repaired++;
      }
    }
    return { message: `Repaired ${repaired} stuck deposits. You can now run sweepAllConfirmed.` };
  },
});

// ─── One-time mempool cleanup utility ────────────────────────────────────────
// Run once from Convex dashboard to clear stuck pending txs on ANY network.
// Pass the chainId of the network where txs are stuck.

export const clearStuckMempool = action({
  args: { chainId: v.optional(v.number()) },
  handler: async (ctx, args): Promise<{ message: string }> => {
    const gasFunderKey = process.env.GAS_FUNDER_PRIVATE_KEY;
    if (!gasFunderKey) return { message: "Missing GAS_FUNDER_PRIVATE_KEY" };

    const chainId = args.chainId ?? 137; // default Polygon if not specified
    const network: any = await ctx.runQuery(api.networks.getNetworkInfo, { chainId });
    if (!network) return { message: `Network with chainId ${chainId} not found` };

    const provider = getProvider(network);
    const gasFunder = new ethers.Wallet(
      gasFunderKey.startsWith("0x") ? gasFunderKey : "0x" + gasFunderKey,
      provider
    );

    const fees = await getGasFees(chainId, provider);
    // 3x to guarantee replacement of any stuck tx
    const cancelFees: ChainGasFees = fees.gasPrice
      ? { gasPrice: fees.gasPrice * 3n }
      : {
          maxFeePerGas: fees.maxFeePerGas! * 3n,
          maxPriorityFeePerGas: fees.maxPriorityFeePerGas! * 3n,
        };

    const confirmedNonce = await provider.getTransactionCount(gasFunder.address, "latest");
    const pendingNonce = await provider.getTransactionCount(gasFunder.address, "pending");

    console.log(`[Cleanup] ${network.name} — confirmed: ${confirmedNonce}, pending: ${pendingNonce}`);

    if (pendingNonce <= confirmedNonce) return { message: "No stuck transactions found." };

    let cancelled = 0;
    for (let nonce = confirmedNonce; nonce < pendingNonce; nonce++) {
      try {
        const tx = await gasFunder.sendTransaction({
          to: gasFunder.address,
          value: 0n,
          nonce,
          gasLimit: 21000n,
          ...cancelFees,
        });
        console.log(`[Cleanup] Cancelling nonce ${nonce}: ${tx.hash}`);
        await waitForReceipt(provider, tx.hash, 120_000);
        console.log(`[Cleanup] ✅ Nonce ${nonce} cleared`);
        cancelled++;
      } catch (err) {
        console.error(`[Cleanup] ❌ Failed nonce ${nonce}: ${err}`);
      }
    }

    return { message: `Cleared ${cancelled} stuck transaction(s) on ${network.name}.` };
  },
});