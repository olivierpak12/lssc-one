import { mutation, query } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";

// Helper to generate a unique referral code
function generateReferralCode() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let result = "";
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

export const createReferralCode = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("User not found");
    if (user.referralCode) return user.referralCode;

    let code = generateReferralCode();
    // Ensure uniqueness
    let existing = await ctx.db
      .query("users")
      .withIndex("by_referralCode", (q) => q.eq("referralCode", code))
      .unique();
    
    while (existing) {
      code = generateReferralCode();
      existing = await ctx.db
        .query("users")
        .withIndex("by_referralCode", (q) => q.eq("referralCode", code))
        .unique();
    }

    const referralLink = `https://lsscone.com/#/register?ref=${code}`;
    await ctx.db.patch(args.userId, { 
      referralCode: code,
      referralLink: referralLink
    });

    return code;
  },
});

export const getTeamStats = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("User not found");

    const levelA = await ctx.db
      .query("referralTree")
      .withIndex("by_parentId_level", (q) => q.eq("parentId", args.userId).eq("level", 1))
      .collect();

    const levelB = await ctx.db
      .query("referralTree")
      .withIndex("by_parentId_level", (q) => q.eq("parentId", args.userId).eq("level", 2))
      .collect();

    const levelC = await ctx.db
      .query("referralTree")
      .withIndex("by_parentId_level", (q) => q.eq("parentId", args.userId).eq("level", 3))
      .collect();

    const teamMemberIds = [...levelA, ...levelB, ...levelC].map(m => m.userId);
    
    let totalTeamDeposit = 0;
    let totalTeamWithdraw = 0;
    let activeMembers = 0;

    for (const memberId of teamMemberIds) {
        const deposits = await ctx.db.query("deposits")
            .withIndex("by_userId", q => q.eq("userId", memberId))
            .collect();
        const confirmedDeposits = deposits.filter(d => d.status === "confirmed" || d.status === "swept");
        if (confirmedDeposits.length > 0) activeMembers++;
        
        totalTeamDeposit += confirmedDeposits.reduce((acc, d) => {
            const val = parseFloat(d.amount);
            return acc + (isNaN(val) ? 0 : val);
        }, 0) / 1000000;

        const withdrawals = await ctx.db.query("withdrawals")
            .withIndex("by_userId", q => q.eq("userId", memberId))
            .collect();
        totalTeamWithdraw += withdrawals.filter(w => w.status === "completed").reduce((acc, w) => {
            const val = parseFloat(w.amount);
            return acc + (isNaN(val) ? 0 : val);
        }, 0) / 1000000;
    }

    const now = new Date();
    const startOfDay = new Date(now.getFullYear(), now.getMonth(), now.getDate()).getTime();
    
    const todayEarnings = await ctx.db.query("referralCommissions")
        .withIndex("by_toUserId", q => q.eq("toUserId", args.userId))
        .filter(q => q.gte(q.field("createdAt"), startOfDay))
        .collect();

    const todayEarningsSum = todayEarnings.reduce((acc, c) => acc + (c.commissionAmount || 0), 0);

    return {
      totalTeamMembers: teamMemberIds.length,
      levelA: levelA.length,
      levelB: levelB.length,
      levelC: levelC.length,
      totalTeamDeposit,
      totalTeamWithdraw,
      referralBalance: user.referralBalance || 0,
      totalReferralEarnings: user.totalReferralEarnings || 0,
      todayEarnings: todayEarningsSum,
      activeMembers
    };
  },
});

export const getTeamMembers = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const tree = await ctx.db
      .query("referralTree")
      .withIndex("by_parentId", (q) => q.eq("parentId", args.userId))
      .collect();

    const members = [];
    for (const node of tree) {
      const user = await ctx.db.get(node.userId);
      if (user) {
        const deposits = await ctx.db.query("deposits").withIndex("by_userId", q => q.eq("userId", user._id)).collect();
        const withdrawals = await ctx.db.query("withdrawals").withIndex("by_userId", q => q.eq("userId", user._id)).collect();
        
        const depSum = deposits.filter(d => d.status === "confirmed" || d.status === "swept").reduce((acc, d) => {
            const val = parseFloat(d.amount);
            return acc + (isNaN(val) ? 0 : val);
        }, 0) / 1000000;

        const withSum = withdrawals.filter(w => w.status === "completed").reduce((acc, w) => {
            const val = parseFloat(w.amount);
            return acc + (isNaN(val) ? 0 : val);
        }, 0) / 1000000;

        members.push({
          username: user.username || user.email.split('@')[0],
          email: user.email,
          level: node.level,
          depositAmount: depSum,
          withdrawAmount: withSum,
          joinDate: user.createdAt
        });
      }
    }
    return members;
  },
});

export const getReferralEarningsHistory = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const history = await ctx.db
      .query("referralCommissions")
      .withIndex("by_toUserId", (q) => q.eq("toUserId", args.userId))
      .order("desc")
      .collect();

    const result = [];
    for (const h of history) {
      const fromUser = await ctx.db.get(h.fromUserId);
      result.push({
        ...h,
        fromUsername: fromUser?.username || fromUser?.email.split('@')[0] || "Unknown"
      });
    }
    return result;
  },
});

export const getLeaderboard = query({
  handler: async (ctx) => {
    const allUsers = await ctx.db.query("users").collect();
    const sorted = allUsers.sort((a, b) => (b.totalReferralEarnings || 0) - (a.totalReferralEarnings || 0)).slice(0, 10);

    return sorted.map(u => ({
        username: u.username || u.email.split('@')[0],
        totalEarnings: u.totalReferralEarnings || 0,
        teamSize: u.teamSize || 0
    }));
  },
});

export const distributeCommissions = mutation({
  args: { depositId: v.id("deposits") },
  handler: async (ctx, args) => {
    const deposit = await ctx.db.get(args.depositId);
    if (!deposit || (deposit.status !== "confirmed" && deposit.status !== "swept")) return;

    const existing = await ctx.db.query("referralCommissions")
        .withIndex("by_depositId", q => q.eq("depositId", args.depositId))
        .first();
    if (existing) return;

    const user = await ctx.db.get(deposit.userId);
    if (!user || !user.referredBy) return;

    const rawAmount = parseFloat(deposit.amount);
    const depositAmount = (isNaN(rawAmount) ? 0 : rawAmount) / 1000000;

    await processCommission(ctx, user.referredBy, user._id, 1, 18, depositAmount, args.depositId);

    const level1Parent = await ctx.db.get(user.referredBy);
    if (level1Parent?.referredBy) {
        await processCommission(ctx, level1Parent.referredBy, user._id, 2, 3, depositAmount, args.depositId);
        
        const level2Parent = await ctx.db.get(level1Parent.referredBy);
        if (level2Parent?.referredBy) {
            await processCommission(ctx, level2Parent.referredBy, user._id, 3, 1, depositAmount, args.depositId);
        }
    }
  }
});

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
