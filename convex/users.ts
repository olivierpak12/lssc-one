import { mutation, query, MutationCtx } from "./_generated/server";
import { v } from "convex/values";
import { Id } from "./_generated/dataModel";
import { hash, verify } from "./password";

/**
 * Verifies a Google ID Token using Google's TokenInfo API
 */
async function verifyGoogleToken(idToken: string) {
  const response = await fetch(`https://oauth2.googleapis.com/tokeninfo?id_token=${idToken}`);
  if (!response.ok) {
    throw new Error("Invalid Google Token");
  }
  return await response.json();
}

async function generateInviteCode(ctx: MutationCtx): Promise<string> {
  for (let attempt = 0; attempt < 100; attempt++) {
    const code = Math.floor(10000 + Math.random() * 90000).toString();
    const existing = await ctx.db
      .query("users")
      .withIndex("by_inviteCode", (q) => q.eq("myInviteCode", code))
      .unique();
    if (!existing) return code;
  }
  throw new Error("Could not generate unique invite code");
}

function generateReferralCode() {
  const chars = "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789";
  let result = "";
  for (let i = 0; i < 6; i++) {
    result += chars.charAt(Math.floor(Math.random() * chars.length));
  }
  return result;
}

export const checkReferralCode = query({
  args: { code: v.string() },
  handler: async (ctx, args) => {
    if (!args.code || args.code.trim() === "") return { isValid: false };
    let inviter = await ctx.db
      .query("users")
      .withIndex("by_referralCode", (q) => q.eq("referralCode", args.code))
      .unique();
    if (!inviter) {
      inviter = await ctx.db
        .query("users")
        .withIndex("by_inviteCode", (q) => q.eq("myInviteCode", args.code))
        .unique();
    }
    return { 
      isValid: !!inviter,
      username: inviter?.username || inviter?.email.split('@')[0]
    };
  },
});
export const loginWithGoogle = mutation({
  args: { 
    idToken: v.string(),
  },
  handler: async (ctx, args) => {
    const payload = await verifyGoogleToken(args.idToken);
    const email = payload.email;
    const googleId = payload.sub;

    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", email))
      .unique();

    if (user) {
      if (!user.externalId) {
        await ctx.db.patch(user._id, { externalId: googleId, emailVerified: true });
      }
      return { 
        _id: user._id, 
        email: user.email, 
        emailVerified: true,
        role: user.role ?? "user" 
      };
    }

    return { 
      isNewUser: true, 
      email: email, 
      googleId: googleId 
    };
  },
});

export const register = mutation({
  args: { 
    email: v.string(), 
    password: v.optional(v.string()),
    transactionPassword: v.string(),
    invitationCode: v.optional(v.string()),
    googleId: v.optional(v.string()),
    username: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .unique();

    if (existing) throw new Error("User already exists");

    const myInviteCode = await generateInviteCode(ctx);

    let referredBy: Id<"users"> | undefined;
    if (args.invitationCode && args.invitationCode.trim() !== "") {
      let inviter = await ctx.db
        .query("users")
        .withIndex("by_referralCode", (q) => q.eq("referralCode", args.invitationCode))
        .unique();
      if (!inviter) {
        inviter = await ctx.db
          .query("users")
          .withIndex("by_inviteCode", (q) => q.eq("myInviteCode", args.invitationCode))
          .unique();
      }
      if (!inviter) {
        throw new Error("Invalid invitation code. Please provide a valid referral code to continue.");
      }
      referredBy = inviter._id;
    }

    let myReferralCode = generateReferralCode();
    let codeExists = await ctx.db.query("users").withIndex("by_referralCode", q => q.eq("referralCode", myReferralCode)).unique();
    while (codeExists) {
      myReferralCode = generateReferralCode();
      codeExists = await ctx.db.query("users").withIndex("by_referralCode", q => q.eq("referralCode", myReferralCode)).unique();
    }

    const hashedPassword = args.password ? await hash(args.password) : "GOOGLE_AUTH";
    const hashedTransactionPassword = await hash(args.transactionPassword);

    const userId = await ctx.db.insert("users", {
      username: args.username,
      email: args.email,
      password: hashedPassword,
      transactionPassword: hashedTransactionPassword,
      invitationCode: args.invitationCode ?? "",
      myInviteCode: myInviteCode,
      referralCode: myReferralCode,
      referralLink: `https://myapp.com/register?ref=${myReferralCode}`,
      referredBy: referredBy,
      referralBalance: 0,
      totalReferralEarnings: 0,
      teamSize: 0,
      role: "user", 
      externalId: args.googleId,
      emailVerified: args.googleId ? true : false,
      createdAt: Date.now(),
      teamRewardsBalance: "0",
      teamRewardsTotalEarned: "0",
    });

    if (referredBy) {
      await ctx.db.insert("referralTree", {
        userId: userId,
        parentId: referredBy,
        level: 1,
        createdAt: Date.now()
      });
      const parent = await ctx.db.get(referredBy);
      if (parent) await ctx.db.patch(referredBy, { teamSize: (parent.teamSize || 0) + 1 });

      if (parent?.referredBy) {
        await ctx.db.insert("referralTree", {
          userId: userId,
          parentId: parent.referredBy,
          level: 2,
          createdAt: Date.now()
        });
        const grandParent = await ctx.db.get(parent.referredBy);
        if (grandParent) await ctx.db.patch(parent.referredBy, { teamSize: (grandParent.teamSize || 0) + 1 });

        if (grandParent?.referredBy) {
          await ctx.db.insert("referralTree", {
            userId: userId,
            parentId: grandParent.referredBy,
            level: 3,
            createdAt: Date.now()
          });
          const greatGrandParent = await ctx.db.get(grandParent.referredBy);
          if (greatGrandParent) await ctx.db.patch(grandParent.referredBy, { teamSize: (greatGrandParent.teamSize || 0) + 1 });
        }
      }
    }

    return userId;
  },
});

export const login = query({
  args: { email: v.string(), password: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .unique();

    if (!user || !(await verify(args.password, user.password))) {
      throw new Error("Invalid credentials");
    }

    return { 
      _id: user._id, 
      email: user.email, 
      emailVerified: user.emailVerified,
      role: user.role ?? "user" 
    };
  },
});

export const getUser = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const user = await ctx.db.get(args.userId);
    if (!user) return null;
    return {
      _id: user._id,
      email: user.email,
      username: user.username,
      referralCode: user.referralCode,
      referralLink: user.referralLink,
      referralBalance: user.referralBalance,
      totalReferralEarnings: user.totalReferralEarnings,
      teamSize: user.teamSize,
      role: user.role ?? "user",
      emailVerified: user.emailVerified,
      teamRewardsBalance: user.teamRewardsBalance ?? "0",
      teamRewardsTotalEarned: user.teamRewardsTotalEarned ?? "0",
      myInviteCode: user.myInviteCode,
      createdAt: user.createdAt,
    };
  },
});

export const getUserByInviteCode = query({
  args: { code: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_inviteCode", (q) => q.eq("myInviteCode", args.code))
      .unique();
    if (!user) return null;
    return { _id: user._id, email: user.email };
  },
});

export const listUsers = query({
  handler: async (ctx) => {
    const users = await ctx.db.query("users").collect();
    return users.map(({ password, transactionPassword, ...u }) => ({
      ...u, 
      role: u.role ?? "user"
    }));
  },
});

export const setRole = mutation({
  args: { userId: v.id("users"), role: v.union(v.literal("user"), v.literal("admin")) },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.userId, { role: args.role });
  },
});

export const makeAdmin = mutation({
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .unique();
    if (!user) throw new Error("User not found");
    await ctx.db.patch(user._id, { role: "admin" });
    return "User is now an admin";
  },
});

export const verifyEmail = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.userId, { emailVerified: true });
  },
});
