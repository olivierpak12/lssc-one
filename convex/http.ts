import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { api } from "./_generated/api";

const http = httpRouter();

const ALLOWED_ORIGINS = [
  "http://localhost:5199",
  "http://localhost:3000",
  "http://127.0.0.1:5199",
  "http://127.0.0.1:3000",
  "https://www.lsscone.com",
  "https://lsscone.com",
];

const getCorsOrigin = (origin: string | null): string => {
  if (origin && ALLOWED_ORIGINS.includes(origin)) return origin;
  if (origin) return origin;
  return ALLOWED_ORIGINS[0];
};

const corsHeaders = (origin: string | null) => ({
  "Access-Control-Allow-Origin": getCorsOrigin(origin),
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS, PUT, DELETE",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
  "Access-Control-Allow-Credentials": "true",
  "Access-Control-Max-Age": "86400",
});

const jsonResponse = (data: any, status: number = 200, origin?: string | null) => {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...corsHeaders(origin ?? null),
    },
  });
};

const corsResponse = (origin?: string | null) =>
  new Response(null, { status: 204, headers: corsHeaders(origin ?? null) });

const getOrigin = (request: Request) => request.headers.get("Origin");

const preflightHandler = httpAction(async (_ctx, request) =>
  corsResponse(getOrigin(request))
);

http.route({ path: "/mutation/users:register", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/users:login", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/users:getUser", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/users:listUsers", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/users:setRole", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/users:loginWithGoogle", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/users:verifyEmail", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/users:checkReferralCode", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/wallets:getWallet", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/action/walletActions:generateWallet", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/balances:getTotalUsdtBalance", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/balances:getWithdrawableBalance", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/deposits:listDeposits", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/withdrawals:getWithdrawals", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/withdrawals:requestWithdrawal", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/action/etherscanActions:syncUserDeposits", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/admin:getStats", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/admin:getPendingWithdrawals", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/networks:getActiveNetworks", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/teams:getTeamStats", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/bikes:getUserPurchases", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/bikes:buyBike", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/bikes:claimDailyEarnings", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/users:requestPasswordReset", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/users:resetPassword", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/users:requestTransactionPasswordReset", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/users:resetTransactionPassword", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/action/withdrawalActions:processWithdrawal", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/action/withdrawalActions:processAllPending", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/referrals:getTeamStats", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/referrals:getTeamMembers", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/referrals:getReferralEarningsHistory", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/referrals:getLeaderboard", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/networks:getAllNetworks", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/messages:list", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/run/messages:unreadCount", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/messages:markRead", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/messages:markAllRead", method: "OPTIONS", handler: preflightHandler });
http.route({ path: "/mutation/messages:remove", method: "OPTIONS", handler: preflightHandler });

http.route({
  path: "/mutation/users:register",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    const cleanBody = Object.fromEntries(
      Object.entries(body).filter(([_, v]) => v !== null)
    ) as any;
    try {
      const result = await ctx.runMutation(api.users.register, cleanBody);
      return jsonResponse({ _id: result }, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/users:login",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      const result = await ctx.runQuery(api.users.login, body);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 401, origin);
    }
  }),
});

http.route({
  path: "/run/users:checkReferralCode",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const code = searchParams.get("code");
      if (!code) return jsonResponse("Missing code", 400, origin);
      const result = await ctx.runQuery(api.users.checkReferralCode, { code });
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/users:getUser",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const userId = searchParams.get("userId");
      if (!userId) return jsonResponse("Missing userId", 400, origin);
      const result = await ctx.runQuery(api.users.getUser, { userId: userId as any });
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/users:listUsers",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const result = await ctx.runQuery(api.users.listUsers);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/networks:getActiveNetworks",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      await ctx.runMutation(api.init.initializeNetworks);
      await ctx.runAction(api.init.applyNetworkMode);
      const result = await ctx.runQuery(api.networks.getActiveNetworks);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/networks:getAllNetworks",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      await ctx.runMutation(api.init.initializeNetworks);
      const result = await ctx.runQuery(api.networks.getAllNetworks);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/mutation/users:setRole",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const body = await request.json();
      await ctx.runMutation(api.users.setRole, body);
      return jsonResponse({ success: true }, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/mutation/users:loginWithGoogle",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      const result = await ctx.runMutation(api.users.loginWithGoogle, body);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/mutation/users:verifyEmail",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const body = await request.json();
      await ctx.runMutation(api.users.verifyEmail, body);
      return new Response(null, { status: 200, headers: corsHeaders(origin) });
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/mutation/users:requestPasswordReset",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    const appUrl = origin || "http://localhost:5199";
    try {
      const { email, token } = await ctx.runMutation(api.resetPassword.requestPasswordReset, { email: body.email });
      await ctx.runAction(api.email.sendPasswordResetEmail, { email, token, appUrl });
      return jsonResponse({ message: "If the email exists, a reset link has been sent." }, 200, origin);
    } catch (e: any) {
      return jsonResponse({ message: "If the email exists, a reset link has been sent." }, 200, origin);
    }
  }),
});

http.route({
  path: "/mutation/users:resetPassword",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      await ctx.runMutation(api.resetPassword.resetPassword, { token: body.token, newPassword: body.newPassword });
      return jsonResponse({ success: true }, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/mutation/users:requestTransactionPasswordReset",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    const appUrl = origin || "http://localhost:5199";
    try {
      const { email, token } = await ctx.runMutation(api.resetPassword.requestTransactionPasswordReset, { email: body.email });
      await ctx.runAction(api.email.sendTransactionPasswordResetEmail, { email, token, appUrl });
      return jsonResponse({ message: "If the email exists, a reset link has been sent." }, 200, origin);
    } catch (e: any) {
      return jsonResponse({ message: "If the email exists, a reset link has been sent." }, 200, origin);
    }
  }),
});

http.route({
  path: "/mutation/users:resetTransactionPassword",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      await ctx.runMutation(api.resetPassword.resetTransactionPassword, { token: body.token, newPassword: body.newPassword });
      return jsonResponse({ success: true }, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/wallets:getWallet",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const userId = searchParams.get("userId");
      if (!userId) return jsonResponse("Missing userId", 400, origin);

      const wallet = await ctx.runQuery(api.wallets.getWallet, { userId: userId as any });
      return jsonResponse(wallet, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/action/walletActions:generateWallet",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      const result = await ctx.runAction(api.walletActions.generateWallet, body);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/balances:getTotalUsdtBalance",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const userId = searchParams.get("userId");
      if (!userId) return jsonResponse("Missing userId", 400, origin);

      const balance = await ctx.runQuery(api.balances.getTotalUsdtBalance, { userId: userId as any });
      return jsonResponse({ balance }, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/balances:getWithdrawableBalance",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const userId = searchParams.get("userId");
      if (!userId) return jsonResponse("Missing userId", 400, origin);

      const balance = await ctx.runQuery(api.balances.getWithdrawableBalance, { userId: userId as any });
      return jsonResponse({ balance }, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/deposits:listDeposits",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const userId = searchParams.get("userId");
      if (!userId) return jsonResponse("Missing userId", 400, origin);

      const deposits = await ctx.runQuery(api.deposits.listDeposits, { userId: userId as any });
      return jsonResponse(deposits, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/withdrawals:getWithdrawals",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const userId = searchParams.get("userId");
      if (!userId) return jsonResponse("Missing userId", 400, origin);

      const result = await ctx.runQuery(api.withdrawals.getWithdrawals, { userId: userId as any });
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/bikes:getUserPurchases",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const userId = searchParams.get("userId");
      if (!userId) return jsonResponse("Missing userId", 400, origin);

      const result = await ctx.runQuery(api.bikes.getUserPurchases, { userId: userId as any });
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/mutation/withdrawals:requestWithdrawal",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      const result = await ctx.runMutation(api.withdrawals.requestWithdrawal, body);
      return jsonResponse({ withdrawalId: result }, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/action/etherscanActions:syncUserDeposits",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      const result = await ctx.runAction(api.etherscanActions.syncUserDeposits, body);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/action/withdrawalActions:processWithdrawal",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      const result = await ctx.runAction(api.withdrawalActions.processWithdrawal, body);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/action/withdrawalActions:processAllPending",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const result = await ctx.runAction((api as any).adminActions.processAllPending);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/admin:getStats",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const result = await ctx.runQuery(api.admin.getStats);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/admin:getPendingWithdrawals",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const result = await ctx.runQuery(api.admin.getPendingWithdrawals);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/referrals:getTeamStats",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const userId = searchParams.get("userId");
      if (!userId) return jsonResponse("Missing userId", 400, origin);
      const result = await ctx.runQuery(api.referrals.getTeamStats, { userId: userId as any });
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/referrals:getTeamMembers",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const userId = searchParams.get("userId");
      if (!userId) return jsonResponse("Missing userId", 400, origin);
      const result = await ctx.runQuery(api.referrals.getTeamMembers, { userId: userId as any });
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/referrals:getReferralEarningsHistory",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const userId = searchParams.get("userId");
      if (!userId) return jsonResponse("Missing userId", 400, origin);
      const result = await ctx.runQuery(api.referrals.getReferralEarningsHistory, { userId: userId as any });
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/referrals:getLeaderboard",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const result = await ctx.runQuery(api.referrals.getLeaderboard);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/teams:getTeamStats",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get("userId");
    const period = searchParams.get("period") || "today";
    if (!userId) return jsonResponse("Missing userId", 400, origin);
    const result = await ctx.runQuery(api.teams.getTeamStats, { userId: userId as any, period: period as any });
    return jsonResponse(result, 200, origin);
  }),
});

http.route({
  path: "/mutation/bikes:buyBike",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      const result = await ctx.runMutation(api.bikes.buyBike, body);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/mutation/bikes:claimDailyEarnings",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      const result = await ctx.runMutation(api.bikes.claimDailyEarnings, body);
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/messages:list",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const userId = searchParams.get("userId");
      if (!userId) return jsonResponse("Missing userId", 400, origin);
      const result = await ctx.runQuery(api.messages.list, { userId: userId as any });
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/run/messages:unreadCount",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    try {
      const { searchParams } = new URL(request.url);
      const userId = searchParams.get("userId");
      if (!userId) return jsonResponse("Missing userId", 400, origin);
      const result = await ctx.runQuery(api.messages.unreadCount, { userId: userId as any });
      return jsonResponse(result, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/mutation/messages:markRead",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      await ctx.runMutation(api.messages.markRead, body);
      return jsonResponse({ success: true }, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/mutation/messages:markAllRead",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      await ctx.runMutation(api.messages.markAllRead, { userId: body.userId });
      return jsonResponse({ success: true }, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

http.route({
  path: "/mutation/messages:remove",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const origin = getOrigin(request);
    const body = await request.json();
    try {
      await ctx.runMutation(api.messages.remove, body);
      return jsonResponse({ success: true }, 200, origin);
    } catch (e: any) {
      return jsonResponse(e.message, 400, origin);
    }
  }),
});

export default http;
