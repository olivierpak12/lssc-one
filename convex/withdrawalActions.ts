"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";
import { ethers } from "ethers";
import { getProvider, withRetry } from "./lib/rpcHelpers";

// ─── Shared gas + receipt helpers (same pattern as sweepActions.ts) ──────────

interface PolygonGasFees {
  maxFeePerGas: bigint;
  maxPriorityFeePerGas: bigint;
}

async function getPolygonGasFees(): Promise<PolygonGasFees> {
  const FALLBACK_PRIORITY = ethers.parseUnits("50", "gwei");
  const FALLBACK_MAX = ethers.parseUnits("300", "gwei");

  try {
    const res = await fetch("https://gasstation.polygon.technology/v2");
    if (!res.ok) throw new Error(`Gas station returned ${res.status}`);
    const data = await res.json();

    const priorityGwei = Math.ceil(data.fast.maxPriorityFee * 1.2);
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

// Manual receipt polling — avoids ethers v6 tx.wait() hang bug (issue #4875)
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

// Cancel stuck pending nonces before sending to prevent queue buildup
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

  const cancelFees = {
    maxFeePerGas: fees.maxFeePerGas * 2n,
    maxPriorityFeePerGas: fees.maxPriorityFeePerGas * 2n,
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

// ─── Main withdrawal action ──────────────────────────────────────────────────

export const processWithdrawal = action({
  args: { withdrawalId: v.id("withdrawals") },
  handler: async (ctx, args): Promise<{ success: boolean; txHash?: string; error?: string; message?: string }> => {
    console.log(`[Withdraw] 🚀 Starting process for: ${args.withdrawalId}`);

    try {
      const withdrawal: any = await ctx.runQuery(api.withdrawals.getWithdrawal, {
        withdrawalId: args.withdrawalId,
      });

      if (!withdrawal) {
        return { success: false, message: "Withdrawal not found" };
      }

      if (withdrawal.status !== "pending") {
        console.log(`[Withdraw] Already in status: ${withdrawal.status}`);
        return { success: false, message: `Already ${withdrawal.status}` };
      }

      // Mark as processing before touching the chain
      await ctx.runMutation(api.withdrawals.updateWithdrawalStatus, {
        withdrawalId: withdrawal._id,
        status: "processing",
      });

      const network: any = await ctx.runQuery(api.networks.getNetworkInfo, {
        chainId: withdrawal.chainId,
      });
      if (!network) throw new Error(`Network not supported (ChainId: ${withdrawal.chainId})`);

      const usdtAddress = process.env[network.usdtContractEnv] || network.usdtContract;
      const hotWalletKey = process.env.HOT_WALLET_PRIVATE_KEY;

      if (!usdtAddress) throw new Error(`Missing USDT contract address for ${network.name}`);
      if (!hotWalletKey) throw new Error("HOT_WALLET_PRIVATE_KEY not set in Convex environment variables");

      const provider = getProvider(network);
      const wallet = new ethers.Wallet(
        hotWalletKey.startsWith("0x") ? hotWalletKey : "0x" + hotWalletKey,
        provider
      );

      const usdtContract = new ethers.Contract(
        usdtAddress,
        ["function transfer(address to, uint256 amount) public returns (bool)"],
        wallet
      );

      // ── Fetch correct Polygon EIP-1559 fees ─────────────────────────────
      // CRITICAL: Do NOT use gasPrice or let ethers auto-fill — Polygon needs
      // maxPriorityFeePerGas ≥ 25 gwei minimum or the tx sits in mempool forever.
      const fees = await getPolygonGasFees();

      // ── Clear any stuck nonces on hot wallet before sending ──────────────
      await cancelStuckNonces(wallet, provider, fees);

      // Explicit nonce — never rely on auto-nonce after cancellation
      const txNonce = await provider.getTransactionCount(wallet.address, "latest");
      console.log(
        `[Withdraw] 💸 Sending ${withdrawal.amount} units to ${withdrawal.toAddress} (nonce: ${txNonce})`
      );

      const tx = await withRetry(
        () =>
          usdtContract.transfer(withdrawal.toAddress, withdrawal.amount, {
            gasLimit: 100000n,       // ERC-20 transfer: 65k typical, 100k is safe ceiling
            nonce: txNonce,
            maxFeePerGas: fees.maxFeePerGas,
            maxPriorityFeePerGas: fees.maxPriorityFeePerGas,
            // DO NOT pass gasPrice — mixing with EIP-1559 fields throws in ethers v6
          }),
        "contract.transfer"
      );

      console.log(`[Withdraw] ⏳ Tx broadcast: ${tx.hash} — polling for receipt...`);

      // Manual polling — NOT tx.wait() which hangs on replaced/dropped txs (ethers#4875)
      const receipt = await waitForReceipt(provider, tx.hash, 180_000);

      await ctx.runMutation(api.withdrawals.updateWithdrawalStatus, {
        withdrawalId: withdrawal._id,
        status: "completed",
        txHash: tx.hash,
      });

      console.log(`[Withdraw] ✅ SUCCESS in block ${receipt.blockNumber}: ${tx.hash}`);
      return { success: true, txHash: tx.hash };

    } catch (error: any) {
      console.error("[Withdraw] ❌ FAILED:", error.message);

      try {
        // updateWithdrawalStatus in withdrawals.ts handles the balance refund on "failed".
        // BUG NOTE: the current refund logic only writes to the balances table (chainId=0)
        // and does NOT restore user.referralBalance if the user paid partly from referral.
        // That is a withdrawals.ts bug — tracked separately. The refund here will at minimum
        // restore the earnings portion correctly.
        await ctx.runMutation(api.withdrawals.updateWithdrawalStatus, {
          withdrawalId: args.withdrawalId,
          status: "failed",
          error: error.message || "Unknown error during processing",
        });
      } catch (mutationErr) {
        console.error("[Withdraw] Critical: could not update failed status", mutationErr);
      }

      return { success: false, error: error.message };
    }
  },
});

// ─── Retry stuck withdrawals (admin utility) ────────────────────────────────
// For withdrawals that got stuck as "processing" due to the old tx.wait() bug.
// Resets them to "pending" so processWithdrawal can be re-triggered.

export const retryStuckWithdrawals = action({
  args: {},
  handler: async (ctx): Promise<{ message: string }> => {
    const withdrawalsApi: any = api.withdrawals;
    const allWithdrawals = await ctx.runQuery(withdrawalsApi.getWithdrawalsRaw ?? withdrawalsApi.getWithdrawals, {});

    let retried = 0;
    for (const w of allWithdrawals as any[]) {
      // "processing" that's been stuck > 10 minutes means the action died mid-flight
      const stuckThreshold = Date.now() - 10 * 60 * 1000;
      if (w.status === "processing" && w.createdAt < stuckThreshold) {
        await ctx.runMutation(api.withdrawals.updateWithdrawalStatus, {
          withdrawalId: w._id,
          status: "pending" as any, // reset so processWithdrawal can re-run it
        });
        await ctx.runAction(api.withdrawalActions.processWithdrawal, {
          withdrawalId: w._id,
        });
        retried++;
      }
    }

    return { message: `Retried ${retried} stuck withdrawal(s).` };
  },
});