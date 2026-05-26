import { mutation, query, MutationCtx } from "./_generated/server";
import { v } from "convex/values";

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
  },
  handler: async (ctx, args) => {
    const existing = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .unique();

    if (existing) throw new Error("User already exists");

    const myCode = await generateInviteCode(ctx);

    const userId = await ctx.db.insert("users", {
      email: args.email,
      password: args.password ?? "GOOGLE_AUTH",
      transactionPassword: args.transactionPassword,
      invitationCode: args.invitationCode ?? "",
      myInviteCode: myCode,
      role: "user", 
      externalId: args.googleId,
      emailVerified: args.googleId ? true : false,
      createdAt: Date.now(),
      teamRewardsBalance: "0",
      teamRewardsTotalEarned: "0",
    });

    // Build referral tree from invitation code
    const inviteCode = args.invitationCode ?? "";
    if (inviteCode.trim().length > 0) {
      const code = inviteCode.trim();
      // Look up inviter by 5-digit code first, fall back to email
      let inviter = await ctx.db
        .query("users")
        .withIndex("by_inviteCode", (q) => q.eq("myInviteCode", code))
        .unique();

      if (!inviter) {
        inviter = await ctx.db
          .query("users")
          .withIndex("by_email", (q) => q.eq("email", code))
          .unique();
      }

      if (inviter) {
        const now = Date.now();
        // Tier 1 (Team A) — direct inviter
        await ctx.db.insert("referralTree", {
          referrerId: inviter._id,
          referredId: userId,
          tier: 1,
          createdAt: now,
        });

        // Find Tier 2 (Team B) — inviter's inviter
        const tier1Links = await ctx.db
          .query("referralTree")
          .withIndex("by_referred", (q) => q.eq("referredId", inviter._id))
          .collect();

        if (tier1Links.length > 0) {
          await ctx.db.insert("referralTree", {
            referrerId: tier1Links[0].referrerId,
            referredId: userId,
            tier: 2,
            createdAt: now,
          });

          // Find Tier 3 (Team C) — inviter's inviter's inviter
          const tier2Links = await ctx.db
            .query("referralTree")
            .withIndex("by_referred", (q) => q.eq("referredId", tier1Links[0].referrerId))
            .collect();

          if (tier2Links.length > 0) {
            await ctx.db.insert("referralTree", {
              referrerId: tier2Links[0].referrerId,
              referredId: userId,
              tier: 3,
              createdAt: now,
            });
          }
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

    if (!user || user.password !== args.password) {
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
      role: user.role ?? "user",
      emailVerified: user.emailVerified,
      teamRewardsBalance: user.teamRewardsBalance ?? "0",
      teamRewardsTotalEarned: user.teamRewardsTotalEarned ?? "0",
      myInviteCode: user.myInviteCode,
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
  args: { email: v.string() },
  handler: async (ctx, args) => {
    const user = await ctx.db
      .query("users")
      .withIndex("by_email", (q) => q.eq("email", args.email))
      .unique();
    if (!user) throw new Error("User not found");
    await ctx.db.patch(user._id, { emailVerified: true });
  },
});
