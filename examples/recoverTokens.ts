import * as dotenv from "dotenv";
import { TokenRecoveryService } from "../services/tokenRecoveryService";

dotenv.config();

/**
 * Example: Recover USDT mistakenly sent to a BSC deposit wallet.
 *
 * Prerequisites:
 *   1. ENCRYPTION_KEY set in .env or Convex Dashboard
 *   2. BSC_MAINNET_RPC or BSC_TESTNET_RPC set in .env
 *   3. USE_MAINNET=true|false to pick mainnet/testnet
 *   4. The wallet's encryptedPrivateKey and iv from the wallets table
 *   5. The deposit address and hot wallet address are valid
 *
 * Run:
 *   npx ts-node examples/recoverTokens.ts
 */

async function main() {
  // ── Pull these from the Convex wallets table or admin UI ────────────────
  const encryptedPrivateKey = "c44372aecb0801fb18eab07e32c991c963b6d1f0c6a4a727b05ceaee3a1d1c4d1171961ee838f6187718bf80b028c96aee832f6a87ab05fd42f285a977e2cd2f5ab5da6506d01da70447f5dbee37da98"; // hex string
  const iv = "a1e9da50bb6ad6ef59f86aefd863c4a2"; // hex string
  const depositAddress = "0x965128aa32eC369025E623E9B800054eFeAEa0A7";
  const hotWallet = process.env.HOT_WALLET_ADDRESS!;

  // The BEP-20 token contract address (e.g. USDT on BSC)
  //   BSC Mainnet USDT: 0x55d398326f99059fF775485246999027B3197955
  //   BSC Testnet USDT: 0x337610d27c242501939206584221d8b6308e05be
  const tokenContract = "0x... Token contract address";

  // ── Initialize service ─────────────────────────────────────────────────
  const service = new TokenRecoveryService();

  // ── Execute recovery ───────────────────────────────────────────────────
  const result = await service.recoverTokens({
    encryptedPrivateKey,
    iv,
    expectedDepositAddress: depositAddress,
    destinationHotWallet: hotWallet,
    tokenContractAddress: tokenContract,
  });

  console.log("Recovery result:", JSON.stringify(result, null, 2));

  if (result.success) {
    console.log(`✅ Successfully recovered ${result.transferredAmount} tokens`);
    console.log(`   From:    ${result.sourceWalletAddress}`);
    console.log(`   To:      ${result.destinationHotWallet}`);
    console.log(`   Tx Hash: ${result.transactionHash}`);
  } else {
    console.error(`❌ Recovery failed: ${result.error}`);
  }
}

main().catch((err) => {
  console.error("Fatal error:", err);
  process.exit(1);
});
