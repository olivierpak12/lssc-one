"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";
import { ethers } from "ethers";
import { getProvider, withRetry, getGasFees, ChainGasFees } from "./lib/rpcHelpers";

// ─── Robust tx wait ──────────────────────────────────────────────────────────

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

// ─── Main withdrawal action ──────────────────────────────────────────────────

export const processWithdrawal = action({
  args: { withdrawalId: v.id("withdrawals") },
  handler: async (ctx, args): Promise<{ success: boolean; txHash?: string; error?: string; message?: string }> => {
    console.log(`[Withdraw] 🚀 Starting process for: ${args.withdrawalId}`);

    try {
      const withdrawal: any = await ctx.runQuery(api.withdrawals.getWithdrawal, {
        withdrawalId: args.withdrawalId,
      });

      if (!withdrawal) return { success: false, message: "Withdrawal not found" };

      if (withdrawal.status !== "pending") {
        console.log(`[Withdraw] Already in status: ${withdrawal.status}`);
        return { success: false, message: `Already ${withdrawal.status}` };
      }

      await ctx.runMutation(api.withdrawals.updateWithdrawalStatus, {
        withdrawalId: withdrawal._id,
        status: "processing",
      });

      const network: any = await ctx.runQuery(api.networks.getNetworkInfo, { chainId: withdrawal.chainId });
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

      // ── Fetch correct gas fees for THIS chain ────────────────────────────
      // getGasFees() handles each chain correctly:
      //   Polygon (137) → Polygon gas station oracle, EIP-1559
      //   BSC (56/97)   → legacy gasPrice only (BSC doesn't support EIP-1559)
      //   Ethereum (1)  → standard EIP-1559 via provider.getFeeData()
      //   Others        → EIP-1559 with 30% buffer fallback
      const fees = await getGasFees(network.chainId, provider);

      await cancelStuckNonces(wallet, provider, fees);

      const txNonce = await provider.getTransactionCount(wallet.address, "latest");
      console.log(`[Withdraw] 💸 Sending ${withdrawal.amount} units to ${withdrawal.toAddress} on ${network.name} (nonce: ${txNonce})`);

      const tx = await withRetry(
        () =>
          usdtContract.transfer(withdrawal.toAddress, withdrawal.amount, {
            gasLimit: 100000n,
            nonce: txNonce,
            ...fees,
          }),
        "contract.transfer"
      );

      console.log(`[Withdraw] ⏳ Tx broadcast: ${tx.hash} — polling for receipt...`);
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
// Resets "processing" withdrawals older than 10 min back to "pending" and retries.

export const retryStuckWithdrawals = action({
  args: {},
  handler: async (ctx): Promise<{ message: string }> => {
    const withdrawalsApi: any = api.withdrawals;
    const allWithdrawals = await ctx.runQuery(withdrawalsApi.getWithdrawalsRaw ?? withdrawalsApi.getWithdrawals, {});

    let retried = 0;
    const stuckThreshold = Date.now() - 10 * 60 * 1000;
    for (const w of allWithdrawals as any[]) {
      if (w.status === "processing" && w.createdAt < stuckThreshold) {
        await ctx.runMutation(api.withdrawals.updateWithdrawalStatus, {
          withdrawalId: w._id,
          status: "pending" as any,
        });
        await ctx.runAction(api.withdrawalActions.processWithdrawal, { withdrawalId: w._id });
        retried++;
      }
    }
    return { message: `Retried ${retried} stuck withdrawal(s).` };
  },
});