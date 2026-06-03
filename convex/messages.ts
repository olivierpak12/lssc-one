import { mutation, query } from "./_generated/server";
import { v } from "convex/values";

export const insert = mutation({
  args: {
    userId: v.id("users"),
    type: v.union(v.literal("deposit"), v.literal("withdrawal"), v.literal("commission"), v.literal("system")),
    title: v.string(),
    body: v.string(),
    refId: v.optional(v.string()),
  },
  handler: async (ctx, args) => {
    const { refId, ...rest } = args;
    await ctx.db.insert("messages", {
      ...rest,
      refId: refId ?? "",
      read: false,
      createdAt: Date.now(),
    });
  },
});

export const list = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("messages")
      .withIndex("by_userId", (q) => q.eq("userId", args.userId))
      .order("desc")
      .collect();
  },
});

export const unreadCount = query({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    return await ctx.db
      .query("messages")
      .withIndex("by_userId_read", (q) => q.eq("userId", args.userId).eq("read", false))
      .collect();
  },
});

export const markRead = mutation({
  args: { messageId: v.id("messages") },
  handler: async (ctx, args) => {
    await ctx.db.patch(args.messageId, { read: true });
  },
});

export const markAllRead = mutation({
  args: { userId: v.id("users") },
  handler: async (ctx, args) => {
    const unread = await ctx.db
      .query("messages")
      .withIndex("by_userId_read", (q) => q.eq("userId", args.userId).eq("read", false))
      .collect();
    for (const msg of unread) {
      await ctx.db.patch(msg._id, { read: true });
    }
  },
});

export const remove = mutation({
  args: {
    messageId: v.id("messages"),
    userId: v.id("users"),
  },
  handler: async (ctx, args) => {
    const message = await ctx.db.get(args.messageId);
    if (!message) throw new Error("Message not found");
    if (message.userId !== args.userId) throw new Error("Not authorized to delete this message");
    await ctx.db.delete(args.messageId);
  },
});
