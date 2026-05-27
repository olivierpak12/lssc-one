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

    const totalBalance = balances.reduce((acc, curr) => acc + BigInt(curr.amount), 0n);

    if (totalBalance < amountMicro) {
      throw new Error("Insufficient balance");
    }

    let remaining = amountMicro;
    for (const balance of balances) {
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
