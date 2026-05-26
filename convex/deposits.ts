import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";

export const listDeposits = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("deposits")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .order("desc")
      .collect();
  },
});

export const recordDeposit = mutation({
  args: {
    userId: v.id("users"),
    txHash: v.string(),
    chainId: v.number(),
    network: v.string(),
    amount: v.string(),
    token: v.string(),
    tokenContract: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("deposits")
      .withIndex("by_txHash", (q) => q.eq("txHash", args.txHash))
      .first();
    
    if (existing) {
      return { id: existing._id, status: existing.status, isNew: false };
    }

    const id = await ctx.db.insert("deposits", {
      ...args,
      confirmations: 0,
      status: "pending",
      createdAt: Date.now(),
    });

    return { id, status: "pending", isNew: true };
  },
});

export const updateStatus = mutation({
  args: {
    depositId: v.id("deposits"),
    status: v.union(v.literal("pending"), v.literal("confirmed"), v.literal("failed"), v.literal("swept")),
    sweepTxHash: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const deposit = await ctx.db.get(args.depositId);
    if (!deposit) return;

    // CRITICAL IDEMPOTENCY GUARD:
    // If the caller wants to set it to 'confirmed', but it's already confirmed or swept,
    // do absolutely nothing. This prevents duplicate balance additions.
    if (args.status === "confirmed" && (deposit.status === "confirmed" || deposit.status === "swept")) {
      return;
    }

    const { depositId, ...patch } = args;
    await ctx.db.patch(depositId, patch);

    // Only update balance when first moving to 'confirmed'
    if (args.status === "confirmed" && deposit.status === "pending") {
      const balance = await ctx.db
        .query("balances")
        .withIndex("by_user_chain_token", (q) => 
          q.eq("userId", deposit.userId).eq("chainId", deposit.chainId).eq("tokenSymbol", deposit.token)
        )
        .first();

      if (balance) {
        const newAmount = (BigInt(balance.amount) + BigInt(deposit.amount)).toString();
        await ctx.db.patch(balance._id, { amount: newAmount, updatedAt: Date.now() });
      } else {
        await ctx.db.insert("balances", {
          userId: deposit.userId,
          chainId: deposit.chainId,
          tokenSymbol: deposit.token,
          amount: deposit.amount,
          updatedAt: Date.now(),
        });
      }

      // Trigger team rewards
      await ctx.scheduler.runAfter(0, api.teams.processDepositRewards, {
        depositId: args.depositId,
        userId: deposit.userId,
        amount: deposit.amount,
      });
    }
  },
});

export const getDeposit = query({
  args: { depositId: v.id("deposits") },
  handler: async (ctx, args) => {
    return await ctx.db.get(args.depositId);
  },
});

export const listDepositsRaw = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db.query("deposits").collect();
  },
});

export const listAllConfirmed = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("deposits")
      .filter((q) => q.eq(q.field("status"), "confirmed"))
      .collect();
  },
});
