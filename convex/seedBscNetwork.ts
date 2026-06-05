"use node";

// ─── convex/seedBscNetwork.ts ────────────────────────────────────────────────
// Run this ONCE from Convex dashboard to insert the BSC network record.
// After running, delete or disable this action — it's a one-time seed.

import { action } from "./_generated/server";
import { api } from "./_generated/api";

export const seedBscNetwork = action({
  args: {},
  handler: async (ctx): Promise<{ message: string }> => {
    const networksApi: any = api.networks;

    // Check if BSC already exists
    const existing = await ctx.runQuery(networksApi.getNetworkInfo, { chainId: 56 });
    if (existing) {
      return { message: "BSC network already exists — skipping." };
    }

    await ctx.runMutation(networksApi.insertNetwork, {
      chainId: 56,
      name: "BNB Smart Chain",
      rpcUrl: "BSC_MAINNET_RPC",           // env var name — set the value in Convex dashboard
      defaultRpc: "BSC_MAINNET_DEFAULT_RPC", // fallback env var name
      usdtContract: "0x55d398326f99059fF775485246999027B3197955", // BSC USDT (BEP-20)
      usdtContractEnv: "BSC_USDT_CONTRACT", // optional override via env var
      usdcContract: "0x8AC76a51cc950d9822D68b83fE1Ad97B32Cd580d",  // BSC USDC (BEP-20)
      usdcContractEnv: "BSC_USDC_CONTRACT",
      symbol: "BNB",
      isActive: true,
    });

    return { message: "BSC network inserted successfully." };
  },
});