import { internalQuery } from "./_generated/server";
import { v } from "convex/values";
import { paginationOptsValidator } from "convex/server";

async function sumAmounts(
  ctx: any,
  tableName: "deposits" | "withdrawals",
  statusFilter?: string
) {
  let total = 0n;
  let count = 0;
  let cursor: string | null = null;
  const BATCH_SIZE = 500;

  while (true) {
    const result: { page: any[]; isDone: boolean; continueCursor: string } = await ctx.db
      .query(tableName)
      .order("asc")
      .paginate({ numItems: BATCH_SIZE, cursor });

    if (result.page.length === 0) break;

    for (const record of result.page) {
      if (statusFilter && record.status !== statusFilter) continue;
      total += BigInt(record.amount);
      count++;
    }

    if (result.isDone) break;
    cursor = result.continueCursor;
  }

  return { total, count };
}

export const sumDeposits = internalQuery({
  args: { status: v.optional(v.string()) },
  handler: async (ctx, args) => {
    return await sumAmounts(ctx, "deposits", args.status);
  },
});

export const sumWithdrawals = internalQuery({
  args: { status: v.optional(v.string()) },
  handler: async (ctx, args) => {
    return await sumAmounts(ctx, "withdrawals", args.status);
  },
});
