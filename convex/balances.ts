import { query } from "./_generated/server";
import { v } from "convex/values";

export const getBalances = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("balances")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
  },
});

export const getTotalUsdtBalance = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const balances = await ctx.db
      .query("balances")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
    
    // Sum up balances (stored as strings to avoid precision issues)
    const total = balances.reduce((acc, curr) => acc + BigInt(curr.amount), 0n);
    return total.toString();
  },
});

export const getWithdrawableBalance = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) return "0";

    const earningsBalance = await ctx.db
      .query("balances")
      .withIndex("by_user_chain_token", (q) =>
        q.eq("userId", args.userId).eq("chainId", 0).eq("tokenSymbol", "USDT")
      )
      .first();

    const claimedAmount = earningsBalance ? BigInt(earningsBalance.amount) : 0n;
    const referralMicros = BigInt(Math.round((user.referralBalance ?? 0) * 1000000));
    const total = claimedAmount + referralMicros;
    return total.toString();
  },
});
