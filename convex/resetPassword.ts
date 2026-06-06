import { mutation } from "./_generated/server";
import { v } from "convex/values";
import { hash } from "./password";

export const requestPasswordReset = mutation({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .unique();

    if (!user) {
      throw new Error("No account found with this email");
    }

    const token = crypto.randomUUID();
    const expiresAt = Date.now() + 3600000;

    await ctx.db.insert("passwordResetTokens", {
      email: args.email,
      token,
      expiresAt,
      used: false,
    });

    return { email: args.email, token };
  },
});

export const requestTransactionPasswordReset = mutation({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .unique();

    if (!user) {
      throw new Error("No account found with this email");
    }

    const token = crypto.randomUUID();
    const expiresAt = Date.now() + 3600000;

    await ctx.db.insert("transactionPasswordResetTokens", {
      userId: user._id,
      email: args.email,
      token,
      expiresAt,
      used: false,
    });

    return { email: args.email, token };
  },
});

export const resetTransactionPassword = mutation({
  args: { token: v.string(), newPassword: v.string() },
  handler: async (ctx, args) => {
    if (args.newPassword.length < 6) {
      throw new Error("Transaction password must be at least 6 characters");
    }

    const resetToken = await ctx.db
      .query("transactionPasswordResetTokens")
      .withIndex("by_token", (q) => q.eq("token", args.token))
      .unique();

    if (!resetToken) {
      throw new Error("Invalid or expired reset token");
    }

    if (resetToken.used) {
      throw new Error("This reset link has already been used");
    }

    if (Date.now() > resetToken.expiresAt) {
      throw new Error("This reset link has expired. Please request a new one.");
    }

    const hashed = await hash(args.newPassword);
    await ctx.db.patch(resetToken.userId, { transactionPassword: hashed });
    await ctx.db.patch(resetToken._id, { used: true });

    return true;
  },
});

export const resetPassword = mutation({
  args: { token: v.string(), newPassword: v.string() },
  handler: async (ctx, args) => {
    if (args.newPassword.length < 6) {
      throw new Error("Password must be at least 6 characters");
    }

    const resetToken = await ctx.db
      .query("passwordResetTokens")
      .withIndex("by_token", (q) => q.eq("token", args.token))
      .unique();

    if (!resetToken) {
      throw new Error("Invalid or expired reset token");
    }

    if (resetToken.used) {
      throw new Error("This reset link has already been used");
    }

    if (Date.now() > resetToken.expiresAt) {
      throw new Error("This reset link has expired. Please request a new one.");
    }

    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", resetToken.email))
      .unique();

    if (!user) {
      throw new Error("User not found");
    }

    const hashed = await hash(args.newPassword);
    await ctx.db.patch(user._id, { password: hashed });
    await ctx.db.patch(resetToken._id, { used: true });

    return true;
  },
});
