import { mutation } from "./_generated/server";
import { v } from "convex/values";

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

    return { success: true };
  },
});
