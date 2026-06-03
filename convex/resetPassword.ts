import { mutation, action } from "./_generated/server";
import { v } from "convex/values";
import { api } from "./_generated/api";
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

export const sendPasswordResetEmail = action({
  args: { email: v.string(), token: v.string(), appUrl: v.string() },
  handler: async (ctx, args) => {
    const resetLink = `${args.appUrl}/#/reset-password?token=${args.token}`;

    const html = `
      <!DOCTYPE html>
      <html>
      <head><meta charset="utf-8"></head>
      <body style="font-family: Arial, sans-serif; background: #0f0f0f; margin: 0; padding: 0;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background: #0f0f0f; padding: 40px 20px;">
          <tr>
            <td align="center">
              <table width="480" cellpadding="0" cellspacing="0" style="background: #1a1a1a; border-radius: 16px; padding: 40px;">
                <tr>
                  <td align="center" style="padding-bottom: 24px;">
                    <div style="font-size: 48px; color: #00C853;">&#x1f6e1;</div>
                    <h1 style="color: #ffffff; font-size: 24px; margin: 16px 0 4px;">LSSC ONE</h1>
                    <p style="color: #666; font-size: 13px; margin: 0;">Password Reset</p>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 20px 0; border-top: 1px solid #333;">
                    <p style="color: #ccc; font-size: 14px; line-height: 1.6;">We received a request to reset the password for your LSSC ONE account.</p>
                    <p style="color: #ccc; font-size: 14px; line-height: 1.6;">Click the button below to set a new password. This link expires in <strong>1 hour</strong>.</p>
                    <div style="text-align: center; margin: 32px 0;">
                      <a href="${resetLink}" style="display: inline-block; background: #00C853; color: #000; padding: 14px 36px; border-radius: 10px; text-decoration: none; font-weight: bold; font-size: 15px;">Reset Password</a>
                    </div>
                    <p style="color: #666; font-size: 12px; line-height: 1.5;">If you didn't request this, you can safely ignore this email. Your password won't change unless you click the link above.</p>
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top: 20px; border-top: 1px solid #333; color: #555; font-size: 11px;">
                    LSSC ONE &middot; Secure Digital Asset Management
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    `;

    const apiKey = process.env.RESEND_API_KEY;
    if (!apiKey) {
      console.log(`[PasswordReset] No RESEND_API_KEY configured. Reset link for ${args.email}: ${resetLink}`);
      return { sent: false, message: "Email API not configured" };
    }

    try {
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "LSSC ONE <noreply@resend.dev>",
          to: args.email,
          subject: "Reset Your LSSC ONE Password",
          html,
        }),
      });

      if (!response.ok) {
        const err = await response.text();
        console.error(`[PasswordReset] Resend error: ${err}`);
        return { sent: false, message: "Failed to send email" };
      }

      console.log(`[PasswordReset] Email sent to ${args.email}`);
      return { sent: true };
    } catch (e) {
      console.error(`[PasswordReset] Error: ${e}`);
      return { sent: false, message: "Failed to send email" };
    }
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

export const sendTransactionPasswordResetEmail = action({
  args: { email: v.string(), token: v.string(), appUrl: v.string() },
  handler: async (ctx, args) => {
    const resetLink = `${args.appUrl}/#/reset-transaction-password?token=${args.token}`;

    const html = `
      <!DOCTYPE html>
      <html>
      <head><meta charset="utf-8"></head>
      <body style="font-family: Arial, sans-serif; background: #0f0f0f; margin: 0; padding: 0;">
        <table width="100%" cellpadding="0" cellspacing="0" style="background: #0f0f0f; padding: 40px 20px;">
          <tr>
            <td align="center">
              <table width="480" cellpadding="0" cellspacing="0" style="background: #1a1a1a; border-radius: 16px; padding: 40px;">
                <tr>
                  <td align="center" style="padding-bottom: 24px;">
                    <div style="font-size: 48px; color: #00C853;">&#x1f6e1;</div>
                    <h1 style="color: #ffffff; font-size: 24px; margin: 16px 0 4px;">LSSC ONE</h1>
                    <p style="color: #666; font-size: 13px; margin: 0;">Transaction Password Reset</p>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 20px 0; border-top: 1px solid #333;">
                    <p style="color: #ccc; font-size: 14px; line-height: 1.6;">We received a request to reset the transaction password for your LSSC ONE account.</p>
                    <p style="color: #ccc; font-size: 14px; line-height: 1.6;">Click the button below to set a new transaction password. This link expires in <strong>1 hour</strong>.</p>
                    <div style="text-align: center; margin: 32px 0;">
                      <a href="${resetLink}" style="display: inline-block; background: #00C853; color: #000; padding: 14px 36px; border-radius: 10px; text-decoration: none; font-weight: bold; font-size: 15px;">Reset Transaction Password</a>
                    </div>
                    <p style="color: #666; font-size: 12px; line-height: 1.5;">If you didn't request this, you can safely ignore this email. Your transaction password won't change unless you click the link above.</p>
                  </td>
                </tr>
                <tr>
                  <td align="center" style="padding-top: 20px; border-top: 1px solid #333; color: #555; font-size: 11px;">
                    LSSC ONE &middot; Secure Digital Asset Management
                  </td>
                </tr>
              </table>
            </td>
          </tr>
        </table>
      </body>
      </html>
    `;

    const apiKey = process.env.RESEND_API_KEY;
    if (!apiKey) {
      console.log(`[TransactionPasswordReset] Reset link for ${args.email}: ${resetLink}`);
      return { sent: false, message: "Email API not configured" };
    }

    try {
      const response = await fetch("https://api.resend.com/emails", {
        method: "POST",
        headers: {
          "Authorization": `Bearer ${apiKey}`,
          "Content-Type": "application/json",
        },
        body: JSON.stringify({
          from: "LSSC ONE <noreply@resend.dev>",
          to: args.email,
          subject: "Reset Your LSSC ONE Transaction Password",
          html,
        }),
      });

      if (!response.ok) {
        const err = await response.text();
        console.error(`[TransactionPasswordReset] Resend error: ${err}`);
        return { sent: false, message: "Failed to send email" };
      }

      console.log(`[TransactionPasswordReset] Email sent to ${args.email}`);
      return { sent: true };
    } catch (e) {
      console.error(`[TransactionPasswordReset] Error: ${e}`);
      return { sent: false, message: "Failed to send email" };
    }
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
