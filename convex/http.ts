import { httpRouter } from "convex/server";
import { httpAction } from "./_generated/server";
import { api } from "./_generated/api";

const http = httpRouter();

const CORS_HEADERS = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, GET, OPTIONS",
  "Access-Control-Allow-Headers": "Content-Type, Authorization",
};

// --- Helper for Responses with CORS ---
const jsonResponse = (data: any, status: number = 200) => {
  return new Response(JSON.stringify(data), {
    status,
    headers: {
      "Content-Type": "application/json",
      ...CORS_HEADERS,
    },
  });
};

const corsResponse = () => new Response(null, { status: 204, headers: CORS_HEADERS });

// --- Preflight (OPTIONS) Handlers ---
http.route({ path: "/mutation/users:register", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/users:login", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/users:getUser", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/users:listUsers", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/users:setRole", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/users:loginWithGoogle", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/users:verifyEmail", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/wallets:getWallet", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/action/walletActions:generateWallet", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/balances:getTotalUsdtBalance", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/deposits:listDeposits", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/withdrawals:requestWithdrawal", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/action/etherscanActions:syncUserDeposits", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/admin:getStats", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/run/teams:getTeamStats", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/bikes:buyBike", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/users:requestPasswordReset", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/users:resetPassword", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/users:requestTransactionPasswordReset", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });
http.route({ path: "/mutation/users:resetTransactionPassword", method: "OPTIONS", handler: httpAction(async () => corsResponse()) });

// --- Auth Routes ---

http.route({
  path: "/mutation/users:register",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runMutation(api.users.register, body);
      return jsonResponse({ _id: result });
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

http.route({
  path: "/run/users:login",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runQuery(api.users.login, body);
      return jsonResponse(result);
    } catch (e: any) {
      return jsonResponse(e.message, 401);
    }
  }),
});

http.route({
  path: "/run/users:getUser",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get("userId");
    if (!userId) return jsonResponse("Missing userId", 400);
    const result = await ctx.runQuery(api.users.getUser, { userId: userId as any });
    return jsonResponse(result);
  }),
});

http.route({
  path: "/run/users:listUsers",
  method: "GET",
  handler: httpAction(async (ctx) => {
    const result = await ctx.runQuery(api.users.listUsers);
    return jsonResponse(result);
  }),
});

http.route({
  path: "/mutation/users:setRole",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    await ctx.runMutation(api.users.setRole, body);
    return jsonResponse({ success: true });
  }),
});

http.route({
  path: "/mutation/users:loginWithGoogle",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runMutation(api.users.loginWithGoogle, body);
      return jsonResponse(result);
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

http.route({
  path: "/mutation/users:verifyEmail",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    await ctx.runMutation(api.users.verifyEmail, body);
    return new Response(null, { status: 200, headers: CORS_HEADERS });
  }),
});

http.route({
  path: "/mutation/users:requestPasswordReset",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    const appUrl = request.headers.get("Origin") || "http://localhost:5199";
    try {
      const { email, token } = await ctx.runMutation(api.resetPassword.requestPasswordReset, { email: body.email });
      await ctx.runAction(api.resetPassword.sendPasswordResetEmail, { email, token, appUrl });
      return jsonResponse({ message: "If the email exists, a reset link has been sent." });
    } catch (e: any) {
      return jsonResponse({ message: "If the email exists, a reset link has been sent." });
    }
  }),
});

http.route({
  path: "/mutation/users:resetPassword",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      await ctx.runMutation(api.resetPassword.resetPassword, { token: body.token, newPassword: body.newPassword });
      return jsonResponse({ success: true });
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

http.route({
  path: "/mutation/users:requestTransactionPasswordReset",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    const appUrl = request.headers.get("Origin") || "http://localhost:5199";
    try {
      const { email, token } = await ctx.runMutation(api.resetPassword.requestTransactionPasswordReset, { email: body.email });
      await ctx.runAction(api.resetPassword.sendTransactionPasswordResetEmail, { email, token, appUrl });
      return jsonResponse({ message: "If the email exists, a reset link has been sent." });
    } catch (e: any) {
      return jsonResponse({ message: "If the email exists, a reset link has been sent." });
    }
  }),
});

http.route({
  path: "/mutation/users:resetTransactionPassword",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      await ctx.runMutation(api.resetPassword.resetTransactionPassword, { token: body.token, newPassword: body.newPassword });
      return jsonResponse({ success: true });
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

// --- Wallet Routes ---

http.route({
  path: "/run/wallets:getWallet",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get("userId");
    if (!userId) return jsonResponse("Missing userId", 400);

    const wallet = await ctx.runQuery(api.wallets.getWallet, { userId: userId as any });
    return jsonResponse(wallet);
  }),
});

http.route({
  path: "/action/walletActions:generateWallet",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runAction(api.walletActions.generateWallet, body);
      return jsonResponse(result);
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

// --- Data Routes ---

http.route({
  path: "/run/balances:getTotalUsdtBalance",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get("userId");
    if (!userId) return jsonResponse("Missing userId", 400);
    
    const balance = await ctx.runQuery(api.balances.getTotalUsdtBalance, { userId: userId as any });
    return jsonResponse({ balance });
  }),
});

http.route({
  path: "/run/deposits:listDeposits",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get("userId");
    if (!userId) return jsonResponse("Missing userId", 400);

    const deposits = await ctx.runQuery(api.deposits.listDeposits, { userId: userId as any });
    return jsonResponse(deposits);
  }),
});

http.route({
  path: "/mutation/withdrawals:requestWithdrawal",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runMutation(api.withdrawals.requestWithdrawal, body);
      return jsonResponse({ withdrawalId: result });
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

http.route({
  path: "/action/etherscanActions:syncUserDeposits",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runAction(api.etherscanActions.syncUserDeposits, body);
      return jsonResponse(result);
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

http.route({
  path: "/run/admin:getStats",
  method: "GET",
  handler: httpAction(async (ctx) => {
    const result = await ctx.runQuery(api.admin.getStats);
    return jsonResponse(result);
  }),
});

http.route({
  path: "/run/teams:getTeamStats",
  method: "GET",
  handler: httpAction(async (ctx, request) => {
    const { searchParams } = new URL(request.url);
    const userId = searchParams.get("userId");
    const period = searchParams.get("period") || "today";
    if (!userId) return jsonResponse("Missing userId", 400);
    const result = await ctx.runQuery(api.teams.getTeamStats, { userId: userId as any, period: period as any });
    return jsonResponse(result);
  }),
});

http.route({
  path: "/mutation/bikes:buyBike",
  method: "POST",
  handler: httpAction(async (ctx, request) => {
    const body = await request.json();
    try {
      const result = await ctx.runMutation(api.bikes.buyBike, body);
      return jsonResponse(result);
    } catch (e: any) {
      return jsonResponse(e.message, 400);
    }
  }),
});

export default http;
