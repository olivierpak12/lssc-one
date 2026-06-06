"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import nodemailer from "nodemailer";

function getTransport() {
  const host = process.env.SMTP_HOST || "smtp.gmail.com";
  const port = Number(process.env.SMTP_PORT) || 465;
  const user = process.env.SMTP_USER;
  const pass = process.env.SMTP_PASSWORD;

  if (!user || !pass) {
    throw new Error("SMTP_USER and SMTP_PASSWORD env vars are not configured");
  }

  return nodemailer.createTransport({
    host,
    port,
    secure: port === 465,
    auth: { user, pass },
  });
}

function getFromAddress() {
  const user = process.env.SMTP_USER || "noreply@lssc.local";
  return process.env.SMTP_FROM || `LSSC Global <${user}>`;
}

function passwordResetHtml(resetLink: string) {
  return `
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
                  <h1 style="color: #ffffff; font-size: 24px; margin: 16px 0 4px;">LSSC Global</h1>
                  <p style="color: #666; font-size: 13px; margin: 0;">Password Reset</p>
                </td>
              </tr>
              <tr>
                <td style="padding: 20px 0; border-top: 1px solid #333;">
                  <p style="color: #ccc; font-size: 14px; line-height: 1.6;">We received a request to reset the password for your LSSC Global account.</p>
                  <p style="color: #ccc; font-size: 14px; line-height: 1.6;">Click the button below to set a new password. This link expires in <strong>1 hour</strong>.</p>
                  <div style="text-align: center; margin: 32px 0;">
                    <a href="${resetLink}" style="display: inline-block; background: #00C853; color: #000; padding: 14px 36px; border-radius: 10px; text-decoration: none; font-weight: bold; font-size: 15px;">Reset Password</a>
                  </div>
                  <p style="color: #666; font-size: 12px; line-height: 1.5;">If you didn't request this, you can safely ignore this email. Your password won't change unless you click the link above.</p>
                </td>
              </tr>
              <tr>
                <td align="center" style="padding-top: 20px; border-top: 1px solid #333; color: #555; font-size: 11px;">
                  LSSC Global &middot; Secure Digital Asset Management
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
  `;
}

function transactionPasswordResetHtml(resetLink: string) {
  return `
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
                  <h1 style="color: #ffffff; font-size: 24px; margin: 16px 0 4px;">LSSC Global</h1>
                  <p style="color: #666; font-size: 13px; margin: 0;">Transaction Password Reset</p>
                </td>
              </tr>
              <tr>
                <td style="padding: 20px 0; border-top: 1px solid #333;">
                  <p style="color: #ccc; font-size: 14px; line-height: 1.6;">We received a request to reset the transaction password for your LSSC Global account.</p>
                  <p style="color: #ccc; font-size: 14px; line-height: 1.6;">Click the button below to set a new transaction password. This link expires in <strong>1 hour</strong>.</p>
                  <div style="text-align: center; margin: 32px 0;">
                    <a href="${resetLink}" style="display: inline-block; background: #00C853; color: #000; padding: 14px 36px; border-radius: 10px; text-decoration: none; font-weight: bold; font-size: 15px;">Reset Transaction Password</a>
                  </div>
                  <p style="color: #666; font-size: 12px; line-height: 1.5;">If you didn't request this, you can safely ignore this email. Your transaction password won't change unless you click the link above.</p>
                </td>
              </tr>
              <tr>
                <td align="center" style="padding-top: 20px; border-top: 1px solid #333; color: #555; font-size: 11px;">
                  LSSC Global &middot; Secure Digital Asset Management
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
  `;
}

export const sendPasswordResetEmail = action({
  args: { email: v.string(), token: v.string(), appUrl: v.string() },
  handler: async (_ctx, args) => {
    const resetLink = `${args.appUrl}/#/reset-password?token=${args.token}`;
    try {
      const transport = getTransport();
      await transport.sendMail({
        from: getFromAddress(),
        to: args.email,
        subject: "Reset Your LSSC Global Password",
        html: passwordResetHtml(resetLink),
      });
      console.log(`[PasswordReset] Email sent to ${args.email}`);
      return { sent: true };
    } catch (e) {
      console.error(`[PasswordReset] SMTP error: ${e}`);
      return { sent: false, message: "Failed to send email" };
    }
  },
});

export const sendTransactionPasswordResetEmail = action({
  args: { email: v.string(), token: v.string(), appUrl: v.string() },
  handler: async (_ctx, args) => {
    const resetLink = `${args.appUrl}/#/reset-transaction-password?token=${args.token}`;
    try {
      const transport = getTransport();
      await transport.sendMail({
        from: getFromAddress(),
        to: args.email,
        subject: "Reset Your LSSC Global Transaction Password",
        html: transactionPasswordResetHtml(resetLink),
      });
      console.log(`[TransactionPasswordReset] Email sent to ${args.email}`);
      return { sent: true };
    } catch (e) {
      console.error(`[TransactionPasswordReset] SMTP error: ${e}`);
      return { sent: false, message: "Failed to send email" };
    }
  },
});
