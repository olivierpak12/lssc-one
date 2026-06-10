import { action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";

export const processPendingAdminWithdrawal = action({
  args: {
    pendingAdminWithdrawalId: v.id("pendingAdminWithdrawals"),
  },
  handler: async (ctx, args): Promise<{ success: boolean; message: string }> => {
    const pending = await ctx.runQuery(api.admin.getPendingAdminWithdrawalById, {
      id: args.pendingAdminWithdrawalId,
    });
    if (!pending) return { success: false, message: "Pending admin withdrawal not found" };

    const withdrawalId = pending.withdrawalId;

    // Reset withdrawal to "pending" so processWithdrawal will process it
    await ctx.runMutation(api.admin.resetWithdrawalToPending, { withdrawalId });

    const res: any = await ctx.runAction(api.withdrawalActions.processWithdrawal, {
      withdrawalId,
    });

    if (res.success) {
      await ctx.runMutation(api.admin.deletePendingAdminWithdrawal, { id: args.pendingAdminWithdrawalId });
      return { success: true, message: `Withdrawal processed successfully. Tx: ${res.txHash}` };
    }

    return {
      success: false,
      message: `Processing failed: ${res.error ?? "Unknown error"}. Pending admin withdrawal kept for retry.`,
    };
  },
});

export const processAllPending = action({
  args: {},
  handler: async (ctx): Promise<{ message: string }> => {
    const pending = await ctx.runQuery(api.admin.getPendingWithdrawals);
    console.log(`[Withdraw] 🤖 Auto-processing ${pending.length} pending withdrawals`);
    
    let successCount = 0;
    for (const w of pending) {
      const res: any = await ctx.runAction(api.withdrawalActions.processWithdrawal, { withdrawalId: w._id });
      if (res.success) successCount++;
    }
    return { message: `Processed ${successCount} out of ${pending.length} withdrawals.` };
  },
});
