import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

const BIKE_CATALOG: Record<string, { name: string; price: number; dailyIncome: number }> = {
  a1: { name: "A1", price: 20.0, dailyIncome: 2.0 },
  a2: { name: "A2", price: 100.0, dailyIncome: 6.6 },
  a3: { name: "A3", price: 380.0, dailyIncome: 25.0 },
  b1: { name: "B1", price: 780.0, dailyIncome: 52.0 },
  b2: { name: "B2", price: 1800.0, dailyIncome: 120.0 },
  b3: { name: "B3", price: 4800.0, dailyIncome: 320.0 },
  s1: { name: "S1", price: 12800.0, dailyIncome: 853.0 },
  s2: { name: "S2", price: 25800.0, dailyIncome: 1720.0 },
  s3: { name: "S3", price: 58000.0, dailyIncome: 3850.0 },
};

const BIKE_ORDER = [
  "a1",
  "a2",
  "a3",
  "b1",
  "b2",
  "b3",
  "s1",
  "s2",
  "s3",
];

const UPGRADE_CLOSE_FEE_PERCENT = 2.0;

export const buyBike = mutation({
  args: {
    userId: v.id("users"),
    bikeId: v.string(),
    amount: v.string(),
  },
  handler: async (ctx, args) => {
    const amountMicro = BigInt(Math.round(parseFloat(args.amount) * 1000000));

    const balances = await ctx.db
      .query("balances")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    const purchases = await ctx.db
      .query("purchases")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .collect();

    // Enforce: User can only own ONE package at a time
    if (purchases.length > 1) {
      // Clean up any duplicate purchases (keep the latest)
      const sortedByDate = purchases.sort((a, b) => b.purchasedAt - a.purchasedAt);
      for (let i = 1; i < sortedByDate.length; i++) {
        await ctx.db.delete(sortedByDate[i]._id);
      }
    }

    const totalBalance = balances.reduce((acc, curr) => acc + BigInt(curr.amount), 0n);

    let refundAmount = 0n;
    let currentPurchase = null;
    let currentPackageIndex = -1;

    if (purchases.length > 0) {
      const sortedByDate = purchases.sort((a, b) => b.purchasedAt - a.purchasedAt);
      currentPurchase = sortedByDate[0];
      currentPackageIndex = BIKE_ORDER.indexOf(currentPurchase.bikeId);

      if (purchases.length > 1) {
        for (let i = 1; i < sortedByDate.length; i++) {
          await ctx.db.delete(sortedByDate[i]._id);
        }
      }
    }

    const targetIndex = BIKE_ORDER.indexOf(args.bikeId);
    if (targetIndex < 0) {
      throw new Error("Invalid package selected.");
    }

    const highestAffordablePackageId = Object.entries(BIKE_CATALOG)
      .filter(([, bike]) => totalBalance >= BigInt(Math.round(bike.price * 1000000)))
      .sort((a, b) => BIKE_ORDER.indexOf(b[0]) - BIKE_ORDER.indexOf(a[0]))
      .map(([bikeId]) => bikeId)[0] || null;

    // First purchase - allow the highest affordable package only
    if (currentPurchase === null) {
      if (highestAffordablePackageId === null) {
        throw new Error("Insufficient balance to buy any package.");
      }
      if (args.bikeId !== highestAffordablePackageId) {
        throw new Error(
          `First purchase must be ${highestAffordablePackageId.toUpperCase()} based on your deposit amount.`,
        );
      }
    } else {
      // Upgrading - must be to next package in sequence
      if (targetIndex !== currentPackageIndex + 1) {
        throw new Error("You must upgrade to the next package in sequence.");
      }

      // Calculate refund (98% of current package price)
      const currentBike = BIKE_CATALOG[currentPurchase.bikeId];
      if (currentBike) {
        const feeMultiplier = 1 - UPGRADE_CLOSE_FEE_PERCENT / 100;
        refundAmount = BigInt(Math.round(currentBike.price * feeMultiplier * 1000000));
      }
    }

    const effectiveBalance = totalBalance + refundAmount;
    const bikePriceMicros = BigInt(Math.round(BIKE_CATALOG[args.bikeId]?.price || 0 * 1000000));
    if (effectiveBalance < bikePriceMicros) {
      throw new Error("Insufficient balance");
    }

    // Apply refund if upgrading
    if (refundAmount > 0n && currentPurchase) {
      if (balances.length > 0) {
        const balance = balances[0];
        const currentAmount = BigInt(balance.amount);
        const newAmount = (currentAmount + refundAmount).toString();
        await ctx.db.patch(balance._id, { amount: newAmount, updatedAt: Date.now() });
      } else {
        await ctx.db.insert("balances", {
          userId: args.userId,
          chainId: 1,
          tokenSymbol: "USDT",
          amount: refundAmount.toString(),
          updatedAt: Date.now(),
        });
      }

      // Delete the old purchase and preserve lastClaimedAt
      const lastClaimedAt = currentPurchase.lastClaimedAt;
      await ctx.db.delete(currentPurchase._id);

      // Deduct new package price from balance
      let remaining = bikePriceMicros;
      const updatedBalances = await ctx.db
        .query("balances")
        .withIndex("by_userId", (q) => q.eq("userId", args.userId))
        .collect();

      for (const balance of updatedBalances) {
        if (remaining <= 0n) break;
        const currentAmount = BigInt(balance.amount);
        if (currentAmount > 0n) {
          const toDeduct = remaining < currentAmount ? remaining : currentAmount;
          const newAmount = (currentAmount - toDeduct).toString();
          await ctx.db.patch(balance._id, { amount: newAmount, updatedAt: Date.now() });
          remaining -= toDeduct;
        }
      }

      // Create new purchase with preserved lastClaimedAt
      const bike = BIKE_CATALOG[args.bikeId];
      if (bike) {
        await ctx.db.insert("purchases", {
          userId: args.userId,
          bikeId: args.bikeId,
          bikeName: bike.name,
          equipmentPrice: bike.price,
          dailyIncome: bike.dailyIncome,
          purchasedAt: Date.now(),
          lastClaimedAt: lastClaimedAt,
        });
      }
    } else {
      // First purchase
      let remaining = bikePriceMicros;
      const updatedBalances = await ctx.db
        .query("balances")
        .withIndex("by_userId", (q) => q.eq("userId", args.userId))
        .collect();

      for (const balance of updatedBalances) {
        if (remaining <= 0n) break;
        const currentAmount = BigInt(balance.amount);
        if (currentAmount > 0n) {
          const toDeduct = remaining < currentAmount ? remaining : currentAmount;
          const newAmount = (currentAmount - toDeduct).toString();
          await ctx.db.patch(balance._id, { amount: newAmount, updatedAt: Date.now() });
          remaining -= toDeduct;
        }
      }

      const bike = BIKE_CATALOG[args.bikeId];
      if (bike) {
        await ctx.db.insert("purchases", {
          userId: args.userId,
          bikeId: args.bikeId,
          bikeName: bike.name,
          equipmentPrice: bike.price,
          dailyIncome: bike.dailyIncome,
          purchasedAt: Date.now(),
        });
      }
    }

    return { success: true };
  },
});

export const getUserPurchases = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const purchases = await ctx.db
      .query("purchases")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .order("desc")
      .collect();
    return purchases;
  },
});

export const claimDailyEarnings = mutation({
  args: {
    userId: v.id("users"),
    purchaseId: v.id("purchases"),
  },
  handler: async (ctx, args) => {
    const purchase = await ctx.db.get(args.purchaseId);
    if (!purchase || purchase.userId !== args.userId) {
      throw new Error("Purchase not found");
    }

    const now = Date.now();
    const dayMs = 86400000;

    if (purchase.lastClaimedAt && now - purchase.lastClaimedAt < dayMs) {
      const hoursLeft = Math.ceil((dayMs - (now - purchase.lastClaimedAt)) / 3600000);
      throw new Error(`Claim available again in ${hoursLeft} hours`);
    }

    // Amount to credit: dailyIncome in USDT, convert to micro-USDT
    const earnedAmount = BigInt(Math.round(purchase.dailyIncome * 1000000));

    // Upsert balance record with chainId=0 for claimed earnings
    const existingBalance = await ctx.db
      .query("balances")
      .withIndex("by_user_chain_token", (q) =>
        q.eq("userId", args.userId).eq("chainId", 0).eq("tokenSymbol", "USDT")
      )
      .first();

    if (existingBalance) {
      const newAmount = (BigInt(existingBalance.amount) + earnedAmount).toString();
      await ctx.db.patch(existingBalance._id, { amount: newAmount, updatedAt: now });
    } else {
      await ctx.db.insert("balances", {
        userId: args.userId,
        chainId: 0,
        tokenSymbol: "USDT",
        amount: earnedAmount.toString(),
        updatedAt: now,
      });
    }

    // Update lastClaimedAt
    await ctx.db.patch(args.purchaseId, { lastClaimedAt: now });

    const earnedUsdt = Number(earnedAmount) / 1000000;
    return { success: true, amount: earnedUsdt.toString() };
  },
});
