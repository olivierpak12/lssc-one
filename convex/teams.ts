import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

const TIER_PERCENTAGES: Record<number, number> = {
  1: 18,
  2: 3,
  3: 1,
};

export const processDepositRewards = mutation({
  args: {
    depositId: v.id("deposits"),
    userId: v.id("users"),
    amount: v.string(),
  },
  handler: async (ctx, args) => {
    const referralLinks = await ctx.db
      .query("referralTree")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    const depositAmount = BigInt(args.amount);

    for (const link of referralLinks) {
      const percentage = TIER_PERCENTAGES[link.level];
      if (!percentage) continue;

      const rewardAmount = (depositAmount * BigInt(percentage)) / BigInt(100);

      if (rewardAmount <= BigInt(0)) continue;

      const referrer = await ctx.db.get(link.parentId);
      if (!referrer) continue;

      const currentBalance = BigInt(referrer.teamRewardsBalance ?? "0");
      const currentTotalEarned = BigInt(referrer.teamRewardsTotalEarned ?? "0");

      await ctx.db.patch(link.parentId, {
        teamRewardsBalance: (currentBalance + rewardAmount).toString(),
        teamRewardsTotalEarned: (currentTotalEarned + rewardAmount).toString(),
      });
    }
  },
});

export const getTeamStats = query({
  args: {
    userId: v.id("users"),
    period: v.union(
      v.literal("today"),
      v.literal("yesterday"),
      v.literal("last7days"),
      v.literal("thismonth"),
    ),
  },
  handler: async (ctx, args) => {
    const now = Date.now();
    const dayMs = 86400000;

    let periodStart: number;
    let periodEnd: number = now;

    switch (args.period) {
      case "today": {
        const d = new Date(now);
        periodStart = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
        break;
      }
      case "yesterday": {
        const d = new Date(now - dayMs);
        periodStart = new Date(d.getFullYear(), d.getMonth(), d.getDate()).getTime();
        periodEnd = new Date(new Date(now).getFullYear(), new Date(now).getMonth(), new Date(now).getDate()).getTime();
        break;
      }
      case "last7days": {
        periodStart = now - 7 * dayMs;
        break;
      }
      case "thismonth": {
        const d = new Date(now);
        periodStart = new Date(d.getFullYear(), d.getMonth(), 1).getTime();
        break;
      }
    }

    const tier1Links = await ctx.db
      .query("referralTree")
      .withIndex("by_parentId_level", (q) => q.eq("parentId", args.userId).eq("level", 1))
      .collect();

    const tier2Links = await ctx.db
      .query("referralTree")
      .withIndex("by_parentId_level", (q) => q.eq("parentId", args.userId).eq("level", 2))
      .collect();

    const tier3Links = await ctx.db
      .query("referralTree")
      .withIndex("by_parentId_level", (q) => q.eq("parentId", args.userId).eq("level", 3))
      .collect();

    async function getTeamStatsForLinks(links: typeof tier1Links, tier: number) {
      const memberIds = links.map((l) => l.userId);
      const newMembersInPeriod = links.filter((l) => l.createdAt >= periodStart && l.createdAt <= periodEnd).length;

      let periodRechargeAmount = BigInt(0);
      for (const memberId of memberIds) {
        const deposits = await ctx.db
          .query("deposits")
          .withIndex("by_userId", (q) => q.eq("userId", memberId))
          .filter((q) => q.eq(q.field("status"), "confirmed"))
          .collect();

        for (const dep of deposits) {
          if (dep.createdAt >= periodStart && dep.createdAt <= periodEnd) {
            periodRechargeAmount += BigInt(dep.amount);
          }
        }
      }

      return {
        count: memberIds.length,
        benefitsPct: TIER_PERCENTAGES[tier],
        newMembers: newMembersInPeriod,
        rechargeAmount: periodRechargeAmount.toString(),
      };
    }

    const teamA = await getTeamStatsForLinks(tier1Links, 1);
    const teamB = await getTeamStatsForLinks(tier2Links, 2);
    const teamC = await getTeamStatsForLinks(tier3Links, 3);

    // Summary calculations
    const allMemberIds = [
      ...tier1Links.map((l) => l.userId),
      ...tier2Links.map((l) => l.userId),
      ...tier3Links.map((l) => l.userId),
    ];

    const newMembersTodayStart = new Date(new Date(now).getFullYear(), new Date(now).getMonth(), new Date(now).getDate()).getTime();
    const newMembersToday = [
      ...tier1Links,
      ...tier2Links,
      ...tier3Links,
    ].filter((l) => l.createdAt >= newMembersTodayStart).length;

    let totalRechargeToday = BigInt(0);
    let totalWithdrawalToday = BigInt(0);
    let totalDepositAll = BigInt(0);
    let totalWithdrawalAll = BigInt(0);

    for (const memberId of allMemberIds) {
      const deposits = await ctx.db
        .query("deposits")
        .withIndex("by_userId", (q) => q.eq("userId", memberId))
        .filter((q) => q.eq(q.field("status"), "confirmed"))
        .collect();

      for (const dep of deposits) {
        const depAmount = BigInt(dep.amount);
        totalDepositAll += depAmount;
        if (dep.createdAt >= newMembersTodayStart) {
          totalRechargeToday += depAmount;
        }
      }

      const withdrawals = await ctx.db
        .query("withdrawals")
        .withIndex("by_userId", (q) => q.eq("userId", memberId))
        .filter((q) => q.eq(q.field("status"), "completed"))
        .collect();

      for (const wd of withdrawals) {
        const wdAmount = BigInt(wd.amount);
        totalWithdrawalAll += wdAmount;
        if (wd.createdAt >= newMembersTodayStart) {
          totalWithdrawalToday += wdAmount;
        }
      }
    }

    return {
      teamA,
      teamB,
      teamC,
      summary: {
        newMembersToday,
        teamRechargeToday: totalRechargeToday.toString(),
        teamWithdrawalToday: totalWithdrawalToday.toString(),
        totalMembers: allMemberIds.length,
        totalDeposit: totalDepositAll.toString(),
        totalWithdrawal: totalWithdrawalAll.toString(),
      },
    };
  },
});
