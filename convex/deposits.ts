import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";
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

export const listAllConfirmed = query({
  args: {},
  handler: async (ctx) => {
    return await ctx.db
      .query("deposits")
      .filter((q) => q.eq(q.field("status"), "confirmed"))
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

    const amountFormatted = (BigInt(args.amount) / 1000000n).toString();
    await ctx.scheduler.runAfter(0, api.messages.insert, {
      userId: args.userId,
      type: "deposit",
      title: "Deposit Received",
      body: `Your deposit of ${amountFormatted} ${args.token} has been received and is pending confirmation.`,
      refId: id,
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

    if (args.status === "confirmed" && (deposit.status === "confirmed" || deposit.status === "swept")) {
      return;
    }

    const { depositId, ...patch } = args;
    await ctx.db.patch(depositId, patch);

    if (args.status === "confirmed") {
      const amountFormatted = (BigInt(deposit.amount) / 1000000n).toString();
      await ctx.scheduler.runAfter(0, api.messages.insert, {
        userId: deposit.userId,
        type: "deposit",
        title: "Deposit Confirmed",
        body: `Your deposit of ${amountFormatted} ${deposit.token} has been confirmed and added to your balance.`,
        refId: depositId,
      });
    } else if (args.status === "failed") {
      const amountFormatted = (BigInt(deposit.amount) / 1000000n).toString();
      await ctx.scheduler.runAfter(0, api.messages.insert, {
        userId: deposit.userId,
        type: "deposit",
        title: "Deposit Failed",
        body: `Your deposit of ${amountFormatted} ${deposit.token} has failed.`,
        refId: depositId,
      });
    } else if (args.status === "swept") {
      const amountFormatted = (BigInt(deposit.amount) / 1000000n).toString();
      await ctx.scheduler.runAfter(0, api.messages.insert, {
        userId: deposit.userId,
        type: "deposit",
        title: "Deposit Secured",
        body: `Your deposit of ${amountFormatted} ${deposit.token} has been swept to our secure wallet.`,
        refId: depositId,
      });
    }

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

      await distributeCommissionsInternal(ctx, args.depositId);
    }
  },
});

async function distributeCommissionsInternal(ctx: any, depositId: Id<"deposits">) {
  const deposit = await ctx.db.get(depositId);
  if (!deposit) return;

  const existing = await ctx.db.query("referralCommissions")
    .withIndex("by_depositId", (q: any) => q.eq("depositId", depositId))
    .first();
  if (existing) return;

  const user = await ctx.db.get(deposit.userId);
  if (!user || !user.referredBy) return;

  const depositAmount = parseFloat(deposit.amount) / 1000000;

  // Level 1: 18%
  await processCommission(ctx, user.referredBy, user._id, 1, 18, depositAmount, depositId);

  // Level 2: 3%
  const level1Parent = await ctx.db.get(user.referredBy);
  if (level1Parent?.referredBy) {
    await processCommission(ctx, level1Parent.referredBy, user._id, 2, 3, depositAmount, depositId);
    
    // Level 3: 2%
    const level2Parent = await ctx.db.get(level1Parent.referredBy);
    if (level2Parent?.referredBy) {
      await processCommission(ctx, level2Parent.referredBy, user._id, 3, 2, depositAmount, depositId);
    }
  }
}

async function processCommission(ctx: any, toUserId: Id<"users">, fromUserId: Id<"users">, level: number, percent: number, depositAmount: number, depositId: Id<"deposits">) {
  const commissionAmount = (depositAmount * percent) / 100;
  
  await ctx.db.insert("referralCommissions", {
    fromUserId,
    toUserId,
    level,
    percent,
    depositAmount,
    commissionAmount,
    depositId,
    createdAt: Date.now()
  });

  const recipient = await ctx.db.get(toUserId);
  if (recipient) {
    await ctx.db.patch(toUserId, {
      referralBalance: (recipient.referralBalance || 0) + commissionAmount,
      totalReferralEarnings: (recipient.totalReferralEarnings || 0) + commissionAmount
    });
  }
}

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
