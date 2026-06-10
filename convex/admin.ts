import { query, mutation, action } from "./_generated/server";
import { v } from "convex/values";
import { internal } from "./_generated/api";
import { BIKE_CATALOG, BIKE_ORDER } from "./bikes";

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

export const setUserBalance = mutation({
  args: {
    userId: v.id("users"),
    amount: v.number(),
  },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("User not found");

    // Sum all confirmed/swept deposits per (chainId, token)
    const deposits = await ctx.db
      .query("deposits")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    const depositByKey: Record<string, bigint> = {};
    for (const d of deposits) {
      if (d.status === "confirmed" || d.status === "swept") {
        const key = `${d.chainId}_${d.token}`;
        depositByKey[key] = (depositByKey[key] || 0n) + BigInt(d.amount);
      }
    }

    const totalDeposited = Object.values(depositByKey).reduce((a, b) => a + b, 0n);
    const totalDepositedFormatted = Number(totalDeposited) / 1_000_000;

    if (Math.abs(args.amount - totalDepositedFormatted) > 0.001) {
      throw new Error(
        `Amount ${args.amount} does not match total deposits (${totalDepositedFormatted})`,
      );
    }

    // Set each deposit balance group to match actual deposits
    const log: string[] = [];
    for (const [key, deposited] of Object.entries(depositByKey)) {
      const [chainIdStr, ...tokenParts] = key.split("_");
      const token = tokenParts.join("_");
      const chainId = parseInt(chainIdStr);
      const depositedFormatted = Number(deposited) / 1_000_000;

      const existing = await ctx.db
        .query("balances")
        .withIndex("by_user_chain_token", (q) =>
          q.eq("userId", args.userId).eq("chainId", chainId).eq("tokenSymbol", token),
        )
        .first();

      if (existing) {
        const oldAmount = Number(BigInt(existing.amount)) / 1_000_000;
        await ctx.db.patch(existing._id, {
          amount: deposited.toString(),
          amountUsd: depositedFormatted,
          updatedAt: Date.now(),
        });
        log.push(
          `Updated balance chainId=${chainId} ${token}: ${oldAmount} → ${depositedFormatted}`,
        );
      } else {
        await ctx.db.insert("balances", {
          userId: args.userId,
          chainId,
          tokenSymbol: token,
          amount: deposited.toString(),
          amountUsd: depositedFormatted,
          updatedAt: Date.now(),
        });
        log.push(`Created balance chainId=${chainId} ${token}: 0 → ${depositedFormatted}`);
      }
    }

    // ── Match purchase to what user can actually afford ──
    const highestAffordable = Object.entries(BIKE_CATALOG)
      .filter(([, bike]) => totalDepositedFormatted >= bike.price)
      .sort((a, b) => BIKE_ORDER.indexOf(b[0]) - BIKE_ORDER.indexOf(a[0]))
      .map(([id]) => id)[0] ?? null;

    const existingPurchases = await ctx.db
      .query("purchases")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    const currentPurchase = existingPurchases[0] ?? null;

    if (highestAffordable) {
      const bike = BIKE_CATALOG[highestAffordable];
      if (currentPurchase) {
        if (currentPurchase.bikeId !== highestAffordable) {
          const oldBike = currentPurchase.bikeId.toUpperCase();
          await ctx.db.patch(currentPurchase._id, {
            bikeId: highestAffordable,
            bikeName: bike.name,
            equipmentPrice: bike.price,
            dailyIncome: bike.dailyIncome,
            purchasedAt: Date.now(),
          });
          log.push(
            `Updated purchase: ${oldBike} → ${bike.name} ($${bike.price})`,
          );
        } else {
          log.push(`Purchase already correct: ${bike.name} ($${bike.price})`);
        }
      } else {
        await ctx.db.insert("purchases", {
          userId: args.userId,
          bikeId: highestAffordable,
          bikeName: bike.name,
          equipmentPrice: bike.price,
          dailyIncome: bike.dailyIncome,
          purchasedAt: Date.now(),
        });
        log.push(`Created purchase: ${bike.name} ($${bike.price})`);
      }
    } else {
      if (currentPurchase) {
        const oldBike = currentPurchase.bikeId.toUpperCase();
        await ctx.db.delete(currentPurchase._id);
        log.push(
          `Deleted purchase: ${oldBike} — insufficient deposit ($${totalDepositedFormatted})`,
        );
      } else {
        log.push(
          `No purchase — insufficient deposit ($${totalDepositedFormatted})`,
        );
      }
    }

    return { success: true, totalDeposited: totalDepositedFormatted, log };
  },
});

export const recalculateUser = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) throw new Error("User not found");

    // ── 1. Sum deposits per (chainId, token) ──
    const deposits = await ctx.db
      .query("deposits")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    const depositByKey: Record<string, bigint> = {};
    for (const d of deposits) {
      if (d.status === "confirmed" || d.status === "swept") {
        const key = `${d.chainId}_${d.token}`;
        depositByKey[key] = (depositByKey[key] || 0n) + BigInt(d.amount);
      }
    }
    const totalDeposited = Object.values(depositByKey).reduce((a, b) => a + b, 0n);

    // ── 2. Sum purchases ──
    const purchases = await ctx.db
      .query("purchases")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
    const totalBikeCost = purchases.reduce(
      (acc, p) => acc + BigInt(Math.round(p.equipmentPrice * 1_000_000)),
      0n,
    );

    // ── 3. Current earnings balance (chainId=0) — keep untouched ──
    const earningsBalance = await ctx.db
      .query("balances")
      .withIndex("by_user_chain_token", (q) =>
        q.eq("userId", args.userId).eq("chainId", 0).eq("tokenSymbol", "USDT"),
      )
      .first();
    const currentEarningsMicro = earningsBalance ? BigInt(earningsBalance.amount) : 0n;

    // ── 4. Recalculate deposit balances (chainId > 0) ──
    // Deduction order in bikes.ts sweeps ALL balances (deposit + earnings).
    // To reconstruct the correct deposit balance:
    //   depositBalance = totalDeposited - (bike cost that deposits covered)
    //   bikeCostFromDeposits = max(0, totalBikeCost - earningsAvaialbleAtPurchaseTime)
    // We don't know the exact split, so we use current state as the best estimate:
    //   deposits covered = max(0, totalBikeCost - currentEarnings - totalWithdrawn)

    const completedWithdrawals = await ctx.db
      .query("withdrawals")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
    const totalWithdrawn = completedWithdrawals
      .filter((w) => w.status === "completed")
      .reduce((acc, w) => acc + BigInt(w.amount), 0n);

    const bikeFundedByEarnings = currentEarningsMicro + totalWithdrawn;
    const bikeFundedByDeposits =
      totalBikeCost > bikeFundedByEarnings
        ? totalBikeCost - bikeFundedByEarnings
        : 0n;

    let remainingDeposit = totalDeposited - bikeFundedByDeposits;
    if (remainingDeposit < 0n) remainingDeposit = 0n;

    // Upsert each deposit-balance group
    for (const [key, deposited] of Object.entries(depositByKey)) {
      const [chainIdStr, ...tokenParts] = key.split("_");
      const token = tokenParts.join("_");
      const chainId = parseInt(chainIdStr);

      let groupBalance = 0n;
      if (totalDeposited > 0n) {
        groupBalance = (deposited * remainingDeposit) / totalDeposited;
      }

      const existing = await ctx.db
        .query("balances")
        .withIndex("by_user_chain_token", (q) =>
          q.eq("userId", args.userId).eq("chainId", chainId).eq("tokenSymbol", token),
        )
        .first();

      if (existing) {
        if (groupBalance > 0n) {
          await ctx.db.patch(existing._id, {
            amount: groupBalance.toString(),
            updatedAt: Date.now(),
          });
        } else {
          await ctx.db.delete(existing._id);
        }
      } else if (groupBalance > 0n) {
        await ctx.db.insert("balances", {
          userId: args.userId,
          chainId,
          tokenSymbol: token,
          amount: groupBalance.toString(),
          updatedAt: Date.now(),
        });
      }
    }

    // ── 5. Recalculate referral totals from commissions ──
    const commissions = await ctx.db
      .query("referralCommissions")
      .withIndex("by_toUserId", (q) => q.eq("toUserId", args.userId))
      .collect();
    const totalCommissionsEarned = commissions.reduce((acc, c) => acc + c.commissionAmount, 0);

    await ctx.db.patch(args.userId, {
      totalReferralEarnings: totalCommissionsEarned,
    });

    // ── 6. Clean up zero-balance docs ──
    const allBalances = await ctx.db
      .query("balances")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();
    for (const b of allBalances) {
      if (BigInt(b.amount) <= 0n) {
        await ctx.db.delete(b._id);
      }
    }

    return {
      success: true,
      summary: {
        totalDeposited: Number(totalDeposited) / 1_000_000,
        totalBikeCost: Number(totalBikeCost) / 1_000_000,
        currentEarnings: Number(currentEarningsMicro) / 1_000_000,
        totalWithdrawn: Number(totalWithdrawn) / 1_000_000,
        bikeFundedByDeposits: Number(bikeFundedByDeposits) / 1_000_000,
        remainingDepositBalance: Number(remainingDeposit) / 1_000_000,
        totalCommissionsEarned,
      },
    };
  },
});

export const setWithdrawalsDisabled = mutation({
  args: {
    disabled: v.boolean(),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("admin_settings")
      .withIndex("by_key", (q) => q.eq("key", "withdrawals_disabled"))
      .first();
    if (existing) {
      await ctx.db.patch(existing._id, { value: args.disabled ? "true" : "false" });
    } else {
      await ctx.db.insert("admin_settings", {
        key: "withdrawals_disabled",
        value: args.disabled ? "true" : "false",
      });
    }
    return { disabled: args.disabled };
  },
});

export const getWithdrawalsDisabled = query({
  handler: async (ctx) => {
    const setting = await ctx.db
      .query("admin_settings")
      .withIndex("by_key", (q) => q.eq("key", "withdrawals_disabled"))
      .first();
    return setting?.value === "true";
  },
});

export const getPendingAdminWithdrawals = query({
  handler: async (ctx) => {
    return await ctx.db
      .query("pendingAdminWithdrawals")
      .order("desc")
      .collect();
  },
});

export const findMismatchedUsers = query({
  handler: async (ctx) => {
    const users = await ctx.db.query("users").collect();
    const allDeposits = await ctx.db.query("deposits").collect();
    const allBalances = await ctx.db.query("balances").collect();
    const allPurchases = await ctx.db.query("purchases").collect();

    // Group by userId
    const depositsByUser: Record<string, typeof allDeposits> = {};
    for (const d of allDeposits) {
      if (d.status === "confirmed" || d.status === "swept") {
        (depositsByUser[d.userId] ??= []).push(d);
      }
    }

    const balancesByUser: Record<string, typeof allBalances> = {};
    for (const b of allBalances) {
      (balancesByUser[b.userId] ??= []).push(b);
    }

    const purchasesByUser: Record<string, typeof allPurchases> = {};
    for (const p of allPurchases) {
      (purchasesByUser[p.userId] ??= []).push(p);
    }

    const mismatches: {
      email: string;
      userId: string;
      totalDeposited: number;
      balanceMismatches: { chainId: number; token: string; deposited: number; current: number }[];
      purchaseMismatch: { has: string; shouldBe: string } | null;
    }[] = [];

    for (const user of users) {
      const userId = user._id;
      const deposits = depositsByUser[userId] ?? [];
      const balances = balancesByUser[userId] ?? [];
      const purchases = purchasesByUser[userId] ?? [];

      // --- Check balance vs deposits per (chainId, token) ---
      const depositSums: Record<string, bigint> = {};
      for (const d of deposits) {
        const key = `${d.chainId}_${d.token}`;
        depositSums[key] = (depositSums[key] ?? 0n) + BigInt(d.amount);
      }

      const balanceMismatches: {
        chainId: number;
        token: string;
        deposited: number;
        current: number;
      }[] = [];

      for (const [key, depositedMicro] of Object.entries(depositSums)) {
        const [chainIdStr, ...tokenParts] = key.split("_");
        const chainId = parseInt(chainIdStr);
        const token = tokenParts.join("_");
        const deposited = Number(depositedMicro) / 1_000_000;

        const balanceDoc = balances.find(
          (b) => b.chainId === chainId && b.tokenSymbol === token,
        );
        const current = balanceDoc ? Number(BigInt(balanceDoc.amount)) / 1_000_000 : 0;

        if (Math.abs(current - deposited) > 0.001) {
          balanceMismatches.push({ chainId, token, deposited, current });
        }
      }

      // Also flag deposit balances that exist but have no deposits
      for (const b of balances) {
        if (b.chainId === 0) continue; // skip earnings balance
        const key = `${b.chainId}_${b.tokenSymbol}`;
        if (!depositSums[key]) {
          const current = Number(BigInt(b.amount)) / 1_000_000;
          if (current > 0.001) {
            balanceMismatches.push({
              chainId: b.chainId,
              token: b.tokenSymbol,
              deposited: 0,
              current,
            });
          }
        }
      }

      // --- Check purchase vs affordability ---
      const totalMicro = Object.values(depositSums).reduce((a, b) => a + b, 0n);
      const totalDeposited = Number(totalMicro) / 1_000_000;

      const highestAffordable =
        Object.entries(BIKE_CATALOG)
          .filter(([, bike]) => totalDeposited >= bike.price)
          .sort(
            (a, b) =>
              BIKE_ORDER.indexOf(b[0]) - BIKE_ORDER.indexOf(a[0]),
          )
          .map(([id]) => id)[0] ?? null;

      let purchaseMismatch: { has: string; shouldBe: string } | null = null;
      const currentPurchase = purchases[0] ?? null;

      if (currentPurchase) {
        const has = `${currentPurchase.bikeId.toUpperCase()} ($${currentPurchase.equipmentPrice})`;
        if (highestAffordable) {
          const bike = BIKE_CATALOG[highestAffordable];
          if (currentPurchase.bikeId !== highestAffordable) {
            purchaseMismatch = {
              has,
              shouldBe: `${bike.name} ($${bike.price})`,
            };
          }
        } else {
          purchaseMismatch = {
            has,
            shouldBe: "none — insufficient deposit",
          };
        }
      } else if (highestAffordable) {
        const bike = BIKE_CATALOG[highestAffordable];
        purchaseMismatch = {
          has: "none",
          shouldBe: `${bike.name} ($${bike.price})`,
        };
      }

      if (balanceMismatches.length > 0 || purchaseMismatch) {
        mismatches.push({
          email: user.email,
          userId,
          totalDeposited,
          balanceMismatches,
          purchaseMismatch,
        });
      }
    }

    return {
      scanned: users.length,
      found: mismatches.length,
      mismatches,
    };
  },
});
