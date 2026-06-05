"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";
import { ethers } from "ethers";
import { getProvider, withRetry } from "./lib/rpcHelpers";

export const processWithdrawal = action({
  args: { withdrawalId: v.id("withdrawals") },
  handler: async (ctx, args): Promise<{ success: boolean; txHash?: string; error?: string; message?: string }> => {
    console.log(`[Withdraw] 🚀 Starting process for: ${args.withdrawalId}`);

    try {
      // 1. Fetch withdrawal record
      const withdrawal: any = await ctx.runQuery(api.withdrawals.getWithdrawal, { 
        withdrawalId: args.withdrawalId 
      });
      
      if (!withdrawal) {
        console.error(`[Withdraw] Withdrawal ${args.withdrawalId} not found`);
        return { success: false, message: "Withdrawal not found" };
      }

      if (withdrawal.status !== "pending") {
        console.log(`[Withdraw] Withdrawal already in status: ${withdrawal.status}`);
        return { success: false, message: `Already ${withdrawal.status}` };
      }

      // 2. Mark as processing (Verifying step in UI)
      await ctx.runMutation(api.withdrawals.updateWithdrawalStatus, {
        withdrawalId: withdrawal._id,
        status: "processing",
      });

      // 3. Get network configuration
      const network: any = await ctx.runQuery(api.networks.getNetworkInfo, { chainId: withdrawal.chainId });
      if (!network) throw new Error(`Network not supported (ChainId: ${withdrawal.chainId})`);

      const usdtAddress = process.env[network.usdtContractEnv] || network.usdtContract;
      const hotWalletKey = process.env.HOT_WALLET_PRIVATE_KEY;

      if (!usdtAddress) throw new Error(`Missing USDT/USDC contract address for ${network.name}`);
      if (!hotWalletKey) throw new Error("HOT_WALLET_PRIVATE_KEY not set in Convex dashboard environment variables.");

      // 4. Setup Provider and Wallet
      const provider = getProvider(network);
      const wallet = new ethers.Wallet(hotWalletKey.startsWith("0x") ? hotWalletKey : "0x" + hotWalletKey, provider);
      
      const usdtContract = new ethers.Contract(
        usdtAddress,
        ["function transfer(address to, uint256 amount) public returns (bool)"],
        wallet
      );

      // 5. Execute On-Chain Transfer
      console.log(`[Withdraw] 💸 Sending ${withdrawal.amount} units to ${withdrawal.toAddress} on ${network.name}`);
      
      const tx = await withRetry(
        () => usdtContract.transfer(withdrawal.toAddress, withdrawal.amount),
        "contract.transfer"
      );
      
      console.log(`[Withdraw] ⏳ Transaction broadcast: ${tx.hash}. Waiting for block confirmation...`);
      const receipt: ethers.TransactionReceipt | null = await withRetry(
        () => tx.wait(),
        "tx.wait"
      );

      if (!receipt) {
        throw new Error("Transaction receipt was not returned by the RPC node");
      }

      if (receipt.status === 0) {
        throw new Error("On-chain transaction failed (reverted)");
      }

      // 6. Finalize Status
      await ctx.runMutation(api.withdrawals.updateWithdrawalStatus, {
        withdrawalId: withdrawal._id,
        status: "completed",
        txHash: tx.hash,
      });

      console.log(`[Withdraw] ✅ SUCCESSFULLY COMPLETED: ${tx.hash}`);
      return { success: true, txHash: tx.hash };

    } catch (error: any) {
      console.error("[Withdraw] ❌ PROCESS FAILED:", error.message);
      
      try {
        await ctx.runMutation(api.withdrawals.updateWithdrawalStatus, {
          withdrawalId: args.withdrawalId,
          status: "failed",
          error: error.message || "Unknown error occurred during processing"
        });
      } catch (mutationErr) {
        console.error("[Withdraw] Critical failure: Could not update error status", mutationErr);
      }
      
      return { success: false, error: error.message };
    }
  },
});
