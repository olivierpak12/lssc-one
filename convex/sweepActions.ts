"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";
import { ethers } from "ethers";
import * as crypto from "crypto";
import { getProvider, withRetry } from "./lib/rpcHelpers";

// ─── Polygon Gas Station ────────────────────────────────────────────────────
// Polygon's EIP-1559 is non-standard. ethers.js defaults maxPriorityFeePerGas
// to 1.5 gwei, but Polygon mainnet requires a MINIMUM of 25 gwei.
// Using gasPrice alone (legacy tx) also causes stuck mempool issues on Polygon.
// The canonical fix is to fetch from Polygon's own gas station oracle.

interface PolygonGasFees {
  maxFeePerGas: bigint;
  maxPriorityFeePerGas: bigint;
}

async function getPolygonGasFees(): Promise<PolygonGasFees> {
  const FALLBACK_PRIORITY = ethers.parseUnits("50", "gwei");  // 50 gwei — safe fallback
  const FALLBACK_MAX = ethers.parseUnits("300", "gwei");      // 300 gwei — covers spikes

  try {
    const res = await fetch("https://gasstation.polygon.technology/v2");
    if (!res.ok) throw new Error(`Gas station returned ${res.status}`);
    const data = await res.json();

    // Use "fast" tier — necessary for sweeps that need reliable inclusion
    const priorityGwei = Math.ceil(data.fast.maxPriorityFee * 1.2); // +20% on top of fast
    const maxGwei = Math.ceil(data.fast.maxFee * 1.2);

    const maxPriorityFeePerGas = ethers.parseUnits(String(priorityGwei), "gwei");
    const maxFeePerGas = ethers.parseUnits(String(maxGwei), "gwei");

    console.log(`[Gas] ⛽ Gas station: priority=${priorityGwei} gwei, maxFee=${maxGwei} gwei`);
    return { maxFeePerGas, maxPriorityFeePerGas };
  } catch (err) {
    console.warn(`[Gas] ⚠️ Gas station fetch failed, using fallback: ${err}`);
    return { maxFeePerGas: FALLBACK_MAX, maxPriorityFeePerGas: FALLBACK_PRIORITY };
  }
}

// ─── Robust tx wait ─────────────────────────────────────────────────────────
// ethers v6 bug: tx.wait() hangs forever if a tx is replaced/dropped (issue #4875).
// We poll manually using getTransactionReceipt instead of relying on wait().

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
      if (receipt.status === 0) {
        throw new Error(`Transaction reverted on-chain: ${txHash}`);
      }
      return receipt;
    }
    await new Promise((r) => setTimeout(r, pollIntervalMs));
  }

  throw new Error(`Transaction not confirmed after ${timeoutMs / 1000}s — hash: ${txHash}`);
}

// ─── Cancel stuck nonces ─────────────────────────────────────────────────────
// Sends 0 POL to self with high gas to cancel any stuck pending txs.
async function cancelStuckNonces(
  wallet: ethers.Wallet,
  provider: ethers.JsonRpcProvider,
  fees: PolygonGasFees
): Promise<void> {
  const confirmedNonce = await provider.getTransactionCount(wallet.address, "latest");
  const pendingNonce = await provider.getTransactionCount(wallet.address, "pending");

  if (pendingNonce <= confirmedNonce) {
    console.log(`[Nonce] ✅ No stuck nonces for ${wallet.address}`);
    return;
  }

  console.warn(
    `[Nonce] ⚠️ Found ${pendingNonce - confirmedNonce} stuck nonce(s) for ${wallet.address} — cancelling...`
  );

  // Use 2x the current fast gas to guarantee replacement
  const cancelFees = {
    maxFeePerGas: (fees.maxFeePerGas * 2n),
    maxPriorityFeePerGas: (fees.maxPriorityFeePerGas * 2n),
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
    const usdtAddress =
      deposit.tokenContract ||
      process.env[(network as any).usdtContractEnv] ||
      network.usdtContract;

    if (!rpcUrl || !usdtAddress) {
      console.error(`[Sweep] ❌ Configuration missing for ${network.name}`);
      return { success: false, message: "Missing RPC or USDT contract" };
    }

    const encryptionKey = process.env.ENCRYPTION_KEY;
    if (!encryptionKey) throw new Error("ENCRYPTION_KEY not set in Convex Dashboard");

    let decryptedKey: string;
    try {
      const iv = Buffer.from(walletData.iv, "hex");
      const decipher = crypto.createDecipheriv(
        "aes-256-cbc",
        Buffer.from(encryptionKey, "utf-8"),
        iv
      );
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

    const usdtContract = new ethers.Contract(
      usdtAddress,
      [
        "function transfer(address to, uint256 amount) public returns (bool)",
        "function balanceOf(address account) public view returns (uint256)",
      ],
      userWallet
    );

    try {
      console.log(
        `[Sweep] 📡 Checking balance for ${userWallet.address} on ${network.name} (Contract: ${usdtAddress})`
      );

      let usdtBalance = await withRetry(
        () => usdtContract.balanceOf(userWallet.address),
        "balanceOf"
      );

      if (usdtBalance === 0n) {
        console.log("[Sweep] ⏳ Balance is 0. Waiting 5s for node sync...");
        await new Promise((r) => setTimeout(r, 5000));
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

      // ─── Fetch correct Polygon EIP-1559 gas fees ──────────────────────────
      // CRITICAL: Do NOT use gasPrice for Polygon. Must use maxFeePerGas +
      // maxPriorityFeePerGas. Polygon requires minimum 25 gwei priority fee.
      const fees = await getPolygonGasFees();

      const gasLimit = 80000n;
      // Cost estimate uses maxFeePerGas (worst case the tx will ever pay)
      const gasNeeded = fees.maxFeePerGas * gasLimit;
      const userNative = await provider.getBalance(userWallet.address);

      console.log(
        `[Sweep] ⛽ Gas needed: ${ethers.formatEther(gasNeeded)} MATIC, user has: ${ethers.formatEther(userNative)} MATIC`
      );

      // ─── Gas funding ──────────────────────────────────────────────────────
      if (userNative < gasNeeded) {
        const funderBalance = await provider.getBalance(gasFunder.address);
        console.log(`[Sweep] 🏦 Gas funder balance: ${ethers.formatEther(funderBalance)} MATIC`);

        if (funderBalance < gasNeeded * 2n) {
          console.error(
            `[Sweep] ❌ Gas funder insufficient. Has: ${ethers.formatEther(funderBalance)}, needs: ${ethers.formatEther(gasNeeded * 2n)}`
          );
          return { success: false, error: "Gas funder wallet has insufficient MATIC." };
        }

        // Clear any stuck nonces on the gas funder before sending
        await cancelStuckNonces(gasFunder, provider, fees);

        // Use explicit "latest" nonce — never rely on auto-nonce after cancellation
        const funderNonce = await provider.getTransactionCount(gasFunder.address, "latest");
        console.log(`[Sweep] ⛽ Funding gas (nonce: ${funderNonce})...`);

        const fundTx = await withRetry(
          () =>
            gasFunder.sendTransaction({
              to: userWallet.address,
              value: gasNeeded * 2n,
              gasLimit: 21000n,  // simple ETH transfer — 21000 is exact
              nonce: funderNonce,
              maxFeePerGas: fees.maxFeePerGas,
              maxPriorityFeePerGas: fees.maxPriorityFeePerGas,
              // DO NOT include gasPrice — mixing gasPrice with EIP-1559 fields
              // causes "both gasPrice and maxFeePerGas specified" error in ethers v6
            }),
          "gasFunder.sendTransaction"
        );

        console.log(`[Sweep] ⛽ Fund tx sent: ${fundTx.hash} — polling for receipt...`);

        // Use manual polling — NOT tx.wait() which hangs forever on replaced txs (ethers#4875)
        const fundReceipt = await waitForReceipt(provider, fundTx.hash, 180_000);
        console.log(`[Sweep] ⛽ Gas funded in block ${fundReceipt.blockNumber}`);
      } else {
        console.log(`[Sweep] ⛽ User wallet already has enough MATIC, skipping gas fund`);
      }

      // ─── Sweep ────────────────────────────────────────────────────────────
      console.log(`[Sweep] 🧹 Sweeping ${ethers.formatUnits(usdtBalance, 6)} USDT to ${hotWalletAddress}`);

      // Clear any stuck nonces on the user wallet before sweeping
      await cancelStuckNonces(userWallet, provider, fees);

      const sweepNonce = await provider.getTransactionCount(userWallet.address, "latest");
      console.log(`[Sweep] 🧹 Sweep nonce: ${sweepNonce}`);

      const sweepTx = await withRetry(
        () =>
          usdtContract.transfer(hotWalletAddress, usdtBalance, {
            gasLimit,
            nonce: sweepNonce,
            maxFeePerGas: fees.maxFeePerGas,
            maxPriorityFeePerGas: fees.maxPriorityFeePerGas,
          }),
        "contract.transfer"
      );

      console.log(`[Sweep] 🧹 Sweep tx sent: ${sweepTx.hash} — polling for receipt...`);

      // Same manual polling — avoids the ethers v6 wait() hang bug
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
// Run this once manually if you have stuck pending transactions piling up.
// Call via Convex dashboard: clearStuckMempool({})

export const clearStuckMempool = action({
  args: {},
  handler: async (ctx): Promise<{ message: string }> => {
    const gasFunderKey = process.env.GAS_FUNDER_PRIVATE_KEY;
    const rpcUrl = process.env.POLYGON_MAINNET_RPC;

    if (!gasFunderKey || !rpcUrl) {
      return { message: "Missing GAS_FUNDER_PRIVATE_KEY or POLYGON_MAINNET_RPC" };
    }

    const provider = new ethers.JsonRpcProvider(rpcUrl);
    const gasFunder = new ethers.Wallet(
      gasFunderKey.startsWith("0x") ? gasFunderKey : "0x" + gasFunderKey,
      provider
    );

    const fees = await getPolygonGasFees();

    // 3x priority to guarantee replacement of any stuck tx
    const cancelFees = {
      maxFeePerGas: fees.maxFeePerGas * 3n,
      maxPriorityFeePerGas: fees.maxPriorityFeePerGas * 3n,
    };

    const confirmedNonce = await provider.getTransactionCount(gasFunder.address, "latest");
    const pendingNonce = await provider.getTransactionCount(gasFunder.address, "pending");

    console.log(`[Cleanup] Confirmed nonce: ${confirmedNonce}, Pending nonce: ${pendingNonce}`);

    if (pendingNonce <= confirmedNonce) {
      return { message: "No stuck transactions found." };
    }

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

    return { message: `Cleared ${cancelled} stuck transaction(s).` };
  },
});