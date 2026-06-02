import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

const BIKE_CATALOG: Record<string, { name: string; price: number; dailyIncome: number }> = {
  beginner: { name: "Beginner period", price: 17.0, dailyIncome: 1.9 },
  blue_s1: { name: "BLUE-S1", price: 57.0, dailyIncome: 6.3 },
  blue_s2: { name: "BLUE-S2", price: 277.0, dailyIncome: 31.0 },
  blue_s3: { name: "BLUE-S3", price: 677.0, dailyIncome: 80.0 },
  blue_s4: { name: "BLUE-S4", price: 1166.0, dailyIncome: 138.0 },
  blue_s5: { name: "BLUE-S5", price: 2266.0, dailyIncome: 268.0 },
  blue_s6: { name: "BLUE-S6", price: 4466.0, dailyIncome: 548.0 },
  blue_s7: { name: "BLUE-S7", price: 7766.0, dailyIncome: 955.0 },
  blue_s8: { name: "BLUE-S8", price: 16888.0, dailyIncome: 2046.0 },
  blue_s9: { name: "BLUE-S9", price: 22888.0, dailyIncome: 2858.0 },
  blue_s10: { name: "BLUE-S10", price: 36888.0, dailyIncome: 4606.0 },
};

const BIKE_ORDER = [
  "beginner",
  "blue_s1",
  "blue_s2",
  "blue_s3",
  "blue_s4",
  "blue_s5",
  "blue_s6",
  "blue_s7",
  "blue_s8",
  "blue_s9",
  "blue_s10",
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

    const totalBalance = balances.reduce((acc, curr) => acc + BigInt(curr.amount), 0n);

    let refundAmount = 0n;
    let highestOwnedIndex = -1;
    for (const purchase of purchases) {
      const index = BIKE_ORDER.indexOf(purchase.bikeId);
      if (index >= 0 && index > highestOwnedIndex) {
        highestOwnedIndex = index;
      }
    }

    const targetIndex = BIKE_ORDER.indexOf(args.bikeId);
    if (targetIndex < 0) {
      throw new Error("Invalid package selected.");
    }

    if (args.bikeId === "beginner") {
      if (highestOwnedIndex >= 0) {
        throw new Error("You already own a package; purchase the next upgrade instead.");
      }
    } else if (highestOwnedIndex < 0) {
      let highestAffordableIndex = -1;
      for (let i = 0; i < BIKE_ORDER.length; i++) {
        const bike = BIKE_CATALOG[BIKE_ORDER[i]];
        if (!bike) continue;
        const bikePriceMicros = BigInt(Math.round(bike.price * 1000000));
        if (totalBalance >= bikePriceMicros) {
          highestAffordableIndex = i;
        }
      }
      if (highestAffordableIndex < 0) {
        throw new Error("Insufficient balance");
      }
      if (targetIndex !== highestAffordableIndex) {
        throw new Error("Only the highest affordable package can be purchased first.");
      }
    } else {
      if (targetIndex !== highestOwnedIndex + 1) {
        throw new Error("You must purchase packages in order.");
      }

      const refundBikeId = BIKE_ORDER[highestOwnedIndex];
      const refundBike = BIKE_CATALOG[refundBikeId];
      if (refundBike) {
        const feeMultiplier = 1 - UPGRADE_CLOSE_FEE_PERCENT / 100;
        refundAmount = BigInt(Math.round(refundBike.price * feeMultiplier * 1000000));
      }
    }

    const effectiveBalance = totalBalance + refundAmount;
    if (effectiveBalance < amountMicro) {
      throw new Error("Insufficient balance");
    }

    let lastClaimedAt: number | undefined;

    if (refundAmount > 0n) {
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

      const refundBikeId = BIKE_ORDER[highestOwnedIndex];
      const refundPurchase = purchases.find((p) => p.bikeId === refundBikeId);
      if (refundPurchase) {
        lastClaimedAt = refundPurchase.lastClaimedAt;
        await ctx.db.delete(refundPurchase._id);
      }
    }

    let remaining = amountMicro;
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
      const newPurchase: any = {
        userId: args.userId,
        bikeId: args.bikeId,
        bikeName: bike.name,
        equipmentPrice: bike.price,
        dailyIncome: bike.dailyIncome,
        purchasedAt: Date.now(),
      };
      if (lastClaimedAt !== undefined) {
        newPurchase.lastClaimedAt = lastClaimedAt;
      }
      await ctx.db.insert("purchases", newPurchase);
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
