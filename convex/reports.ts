import { query } from "./_generated/server";
import { v } from "convex/values";
import { Doc, Id } from "./_generated/dataModel";

export const getUserFullReport = query({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .unique();

    if (!user) {
      throw new Error(`User not found: ${args.email}`);
    }

    const userId = user._id;

    const [deposits, balances, commissions, withdrawals, purchases, referralTree] =
      await Promise.all([
        ctx.db
          .query("deposits")
          .withIndex("by_userId", (q) => q.eq("userId", userId))
          .order("desc")
          .collect(),
        ctx.db
          .query("balances")
          .withIndex("by_userId", (q) => q.eq("userId", userId))
          .collect(),
        ctx.db
          .query("referralCommissions")
          .withIndex("by_toUserId", (q) => q.eq("toUserId", userId))
          .order("desc")
          .collect(),
        ctx.db
          .query("withdrawals")
          .withIndex("by_userId", (q) => q.eq("userId", userId))
          .order("desc")
          .collect(),
        ctx.db
          .query("purchases")
          .withIndex("by_userId", (q) => q.eq("userId", userId))
          .order("desc")
          .collect(),
        ctx.db
          .query("referralTree")
          .withIndex("by_parentId", (q) => q.eq("parentId", userId))
          .collect(),
      ]);

    const fromUserIds = Array.from(new Set(commissions.map((c) => c.fromUserId)));
    const fromUsers = new Map<Id<"users">, string>();
    for (const id of fromUserIds) {
      const u = await ctx.db.get(id);
      if (u && "email" in u) {
        const userDoc = u as Doc<"users">;
        fromUsers.set(id, userDoc.username || userDoc.email.split("@")[0] || "Unknown");
      }
    }

    const teamMemberIds = Array.from(new Set(referralTree.map((t) => t.userId)));
    const teamMemberInfo = new Map<
      Id<"users">,
      { username: string; email: string }
    >();
    for (const id of teamMemberIds) {
      const u = await ctx.db.get(id);
      if (u && "email" in u) {
        const userDoc = u as Doc<"users">;
        teamMemberInfo.set(id, {
          username: userDoc.username || userDoc.email.split("@")[0],
          email: userDoc.email,
        });
      }
    }

    const WITHDRAWAL_FEE = BigInt(250000);
    const MICRO = 1_000_000;

    const totalDepositedMicro = deposits
      .filter((d) => d.status === "confirmed" || d.status === "swept")
      .reduce((acc, d) => acc + BigInt(d.amount), BigInt(0));

    const totalWithdrawnMicro = withdrawals
      .filter((w) => w.status === "completed")
      .reduce((acc, w) => acc + BigInt(w.amount), BigInt(0));

    const totalFeesPaidMicro = withdrawals
      .filter((w) => w.status === "completed")
      .reduce((acc) => acc + WITHDRAWAL_FEE, BigInt(0));

    const totalCommissions = commissions.reduce(
      (acc, c) => acc + c.commissionAmount,
      0,
    );

    const earningsBalance = balances.find(
      (b) => b.chainId === 0 && b.tokenSymbol === "USDT",
    );
    const earningsMicro = earningsBalance ? BigInt(earningsBalance.amount) : BigInt(0);

    return {
      user: {
        _id: user._id,
        _creationTime: user._creationTime,
        email: user.email,
        username: user.username,
        role: user.role ?? "user",
        emailVerified: user.emailVerified,
        createdAt: user.createdAt,
        referralCode: user.referralCode,
        referralLink: user.referralLink,
        myInviteCode: user.myInviteCode,
        teamSize: user.teamSize ?? 0,
        referredBy: user.referredBy,
      },
      summary: {
        totalDeposited: Number(totalDepositedMicro) / MICRO,
        totalWithdrawn: Number(totalWithdrawnMicro) / MICRO,
        totalFeesPaid: Number(totalFeesPaidMicro) / MICRO,
        totalCommissionsEarned: totalCommissions,
        currentEarningsBalance: Number(earningsMicro) / MICRO,
        referralBalance: user.referralBalance ?? 0,
        totalReferralEarnings: user.totalReferralEarnings ?? 0,
        teamRewardsBalance:
          Number(user.teamRewardsBalance ?? "0") / MICRO,
        teamRewardsTotalEarned:
          Number(user.teamRewardsTotalEarned ?? "0") / MICRO,
        netWorth:
          Number(earningsMicro) / MICRO +
          (user.referralBalance ?? 0) +
          Number(user.teamRewardsBalance ?? "0") / MICRO,
      },
      deposits: deposits.map((d) => ({
        _id: d._id,
        _creationTime: d._creationTime,
        amount: Number(BigInt(d.amount)) / MICRO,
        token: d.token,
        network: d.network,
        status: d.status,
        txHash: d.txHash,
        sweepTxHash: d.sweepTxHash,
        confirmations: d.confirmations,
        createdAt: d.createdAt,
      })),
      commissions: commissions.map((c) => ({
        _id: c._id,
        _creationTime: c._creationTime,
        level: c.level,
        percent: c.percent,
        depositAmount: c.depositAmount,
        commissionAmount: c.commissionAmount,
        fromUserId: c.fromUserId,
        fromUsername: fromUsers.get(c.fromUserId) ?? "Unknown",
        createdAt: c.createdAt,
      })),
      withdrawals: withdrawals.map((w) => ({
        _id: w._id,
        _creationTime: w._creationTime,
        amount: Number(BigInt(w.amount)) / MICRO,
        token: w.token,
        network: w.network,
        status: w.status,
        toAddress: w.toAddress,
        txHash: w.txHash,
        error: w.error,
        createdAt: w.createdAt,
      })),
      balances: balances.map((b) => ({
        _id: b._id,
        chainId: b.chainId,
        tokenSymbol: b.tokenSymbol,
        amount: Number(BigInt(b.amount)) / MICRO,
        updatedAt: b.updatedAt,
      })),
      purchases: purchases.map((p) => ({
        _id: p._id,
        _creationTime: p._creationTime,
        bikeId: p.bikeId,
        bikeName: p.bikeName,
        equipmentPrice: p.equipmentPrice,
        dailyIncome: p.dailyIncome,
        purchasedAt: p.purchasedAt,
        lastClaimedAt: p.lastClaimedAt,
      })),
      team: {
        totalMembers: referralTree.length,
        byLevel: {
          1: referralTree
            .filter((t) => t.level === 1)
            .map((t) => ({
              userId: t.userId,
              username: teamMemberInfo.get(t.userId)?.username ?? "Unknown",
              email: teamMemberInfo.get(t.userId)?.email ?? "",
              createdAt: t.createdAt,
            })),
          2: referralTree
            .filter((t) => t.level === 2)
            .map((t) => ({
              userId: t.userId,
              username: teamMemberInfo.get(t.userId)?.username ?? "Unknown",
              email: teamMemberInfo.get(t.userId)?.email ?? "",
              createdAt: t.createdAt,
            })),
          3: referralTree
            .filter((t) => t.level === 3)
            .map((t) => ({
              userId: t.userId,
              username: teamMemberInfo.get(t.userId)?.username ?? "Unknown",
              email: teamMemberInfo.get(t.userId)?.email ?? "",
              createdAt: t.createdAt,
            })),
        },
      },
    };
  },
});
