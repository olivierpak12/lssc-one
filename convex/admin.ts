import { query, action } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";

export const getStats = query({
  handler: async (ctx) => {
    const totalDeposits = await ctx.db.query("deposits").collect();
    const totalWithdrawals = await ctx.db.query("withdrawals").collect();
    
    const pendingWithdrawals = await ctx.db
      .query("withdrawals")
      .filter((q) => q.eq(q.field("status"), "pending"))
      .collect();

    const pendingSweeps = await ctx.db
      .query("deposits")
      .filter((q) => q.eq(q.field("status"), "confirmed"))
      .collect();

    return {
      depositCount: totalDeposits.length,
      withdrawalCount: totalWithdrawals.length,
      pendingWithdrawals: pendingWithdrawals.length,
      pendingSweeps: pendingSweeps.length,
      totalVolume: totalDeposits.reduce((acc, d) => acc + parseFloat(d.amount), 0),
    };
  },
});

export const getPendingWithdrawals = query({
  handler: async (ctx) => {
    return await ctx.db
      .query("withdrawals")
      .filter((q) => q.eq(q.field("status"), "pending"))
      .collect();
  },
});

export const getTotalDeposits = action({
  args: {
    status: v.optional(v.union(v.literal("pending"), v.literal("confirmed"), v.literal("failed"), v.literal("swept"))),
  },
  handler: async (ctx, args) => {
    const result: { total: bigint; count: number } = await ctx.runQuery(internal.adminQueries.sumDeposits, { status: args.status });
    return {
      count: result.count,
      totalMicros: result.total.toString(),
      totalFormatted: (Number(result.total) / 1_000_000).toFixed(2),
    };
  },
});

export const getTotalWithdrawals = action({
  args: {
    status: v.optional(v.union(v.literal("pending"), v.literal("processing"), v.literal("completed"), v.literal("failed"))),
  },
  handler: async (ctx, args) => {
    const result: { total: bigint; count: number } = await ctx.runQuery(internal.adminQueries.sumWithdrawals, { status: args.status });
    return {
      count: result.count,
      totalMicros: result.total.toString(),
      totalFormatted: (Number(result.total) / 1_000_000).toFixed(2),
    };
  },
});

export const getAllTotals = action({
  handler: async (ctx) => {
    const deposits: { total: bigint; count: number } = await ctx.runQuery(internal.adminQueries.sumDeposits, { status: undefined });
    const withdrawals: { total: bigint; count: number } = await ctx.runQuery(internal.adminQueries.sumWithdrawals, { status: undefined });
    const completedWithdrawals: { total: bigint; count: number } = await ctx.runQuery(internal.adminQueries.sumWithdrawals, { status: "completed" });
    const confirmedDeposits: { total: bigint; count: number } = await ctx.runQuery(internal.adminQueries.sumDeposits, { status: "confirmed" });

    return {
      deposits: {
        all: {
          count: deposits.count,
          totalMicros: deposits.total.toString(),
          totalFormatted: (Number(deposits.total) / 1_000_000).toFixed(2),
        },
        confirmed: {
          count: confirmedDeposits.count,
          totalMicros: confirmedDeposits.total.toString(),
          totalFormatted: (Number(confirmedDeposits.total) / 1_000_000).toFixed(2),
        },
      },
      withdrawals: {
        all: {
          count: withdrawals.count,
          totalMicros: withdrawals.total.toString(),
          totalFormatted: (Number(withdrawals.total) / 1_000_000).toFixed(2),
        },
        completed: {
          count: completedWithdrawals.count,
          totalMicros: completedWithdrawals.total.toString(),
          totalFormatted: (Number(completedWithdrawals.total) / 1_000_000).toFixed(2),
        },
      },
      netFlow: {
        totalMicros: (deposits.total - withdrawals.total).toString(),
        totalFormatted: ((Number(deposits.total) - Number(withdrawals.total)) / 1_000_000).toFixed(2),
      },
    };
  },
});
