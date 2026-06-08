"use node";

import { action } from "./_generated/server";
import { v } from "convex/values";
import { ethers } from "ethers";
import * as crypto from "crypto";

// ─── Constants ────────────────────────────────────────────────────────────────

const BSC_MAINNET_CHAIN_ID = 56;
const BSC_TESTNET_CHAIN_ID = 97;

const ERC20_ABI = [
  "function balanceOf(address account) view returns (uint256)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "function decimals() view returns (uint8)",
];

// ─── BSC Gas Fees ─────────────────────────────────────────────────────────────

async function getBscGasFees(
  provider: ethers.JsonRpcProvider,
  chainId: number
): Promise<{ gasPrice: bigint }> {
  const fallbackGasPrice = ethers.parseUnits("3", "gwei");
  try {
    const feeData = await provider.getFeeData();
    const base = feeData.gasPrice ?? fallbackGasPrice;
    return { gasPrice: (base * 120n) / 100n };
  } catch {
    return { gasPrice: fallbackGasPrice };
  }
}

// ─── Tx Wait ──────────────────────────────────────────────────────────────────

async function waitForReceipt(
  provider: ethers.JsonRpcProvider,
  txHash: string,
  timeoutMs: number = 180_000,
  pollIntervalMs: number = 3_000
): Promise<ethers.TransactionReceipt> {
  const deadline = Date.now() + timeoutMs;
  while (Date.now() < deadline) {
    const receipt = await provider.getTransactionReceipt(txHash);
    if (receipt && receipt.status !== null) {
      if (receipt.status === 0) {
        throw new Error(`Transaction reverted on-chain: ${txHash}`);
      }
      return receipt;
    }
    await new Promise((r) => setTimeout(r, pollIntervalMs));
  }
  throw new Error(
    `Transaction not confirmed after ${timeoutMs / 1000}s — hash: ${txHash}`
  );
}

// ─── Action ───────────────────────────────────────────────────────────────────

export const recoverTokens = action({
  args: {
    encryptedPrivateKey: v.string(),
    iv: v.string(),
    expectedDepositAddress: v.string(),
    destinationHotWallet: v.string(),
    tokenContractAddress: v.string(),
    chainId: v.optional(v.number()),
  },
  handler: async (
    _ctx,
    args
  ): Promise<{
    success: boolean;
    sourceWalletAddress?: string;
    destinationHotWallet?: string;
    transactionHash?: string;
    transferredAmount?: string;
    tokenSymbol?: string;
    error?: string;
  }> => {
    console.log("[Recover] Starting token recovery...");

    // ── Validate addresses ──────────────────────────────────────────────────
    if (!ethers.isAddress(args.expectedDepositAddress)) {
      return { success: false, error: "Invalid expectedDepositAddress" };
    }
    if (!ethers.isAddress(args.destinationHotWallet)) {
      return { success: false, error: "Invalid destinationHotWallet" };
    }
    if (!ethers.isAddress(args.tokenContractAddress)) {
      return { success: false, error: "Invalid tokenContractAddress" };
    }

    // ── Read env ────────────────────────────────────────────────────────────
    const encryptionKey = process.env.ENCRYPTION_KEY;
    if (!encryptionKey) {
      return { success: false, error: "ENCRYPTION_KEY not set in Convex environment variables" };
    }

    const isMainnet = process.env.USE_MAINNET !== "false";
    const chainId = args.chainId ?? (isMainnet ? BSC_MAINNET_CHAIN_ID : BSC_TESTNET_CHAIN_ID);

    const rpcUrl =
      chainId === BSC_MAINNET_CHAIN_ID
        ? process.env.BSC_MAINNET_RPC || process.env.BSC_MAINNET_DEFAULT_RPC
        : process.env.BSC_TESTNET_RPC;

    if (!rpcUrl) {
      return {
        success: false,
        error: `No RPC URL configured for BSC chain ID ${chainId}. Set BSC_MAINNET_RPC or BSC_MAINNET_DEFAULT_RPC in Convex environment variables.`,
      };
    }

    // ── Decrypt ─────────────────────────────────────────────────────────────
    let decryptedKey: string | null = null;
    try {
      const decipher = crypto.createDecipheriv(
        "aes-256-cbc",
        Buffer.from(encryptionKey, "utf-8"),
        Buffer.from(args.iv, "hex")
      );
      decryptedKey = decipher.update(args.encryptedPrivateKey, "hex", "utf8");
      decryptedKey += decipher.final("utf8");
      if (!decryptedKey.startsWith("0x")) decryptedKey = "0x" + decryptedKey;
    } catch (e) {
      return {
        success: false,
        error: "Private key decryption failed. Check ENCRYPTION_KEY, encryptedPrivateKey, and iv.",
      };
    }

    try {
      // ── Connect to BSC ──────────────────────────────────────────────────
      const provider = new ethers.JsonRpcProvider(rpcUrl, chainId, {
        staticNetwork: true,
      });
      const wallet = new ethers.Wallet(decryptedKey, provider);

      // ── Verify address ──────────────────────────────────────────────────
      const derivedAddress = wallet.address.toLowerCase();
      const expected = args.expectedDepositAddress.toLowerCase();
      if (derivedAddress !== expected) {
        return {
          success: false,
          sourceWalletAddress: wallet.address,
          error: `Derived address ${wallet.address} does not match expected ${args.expectedDepositAddress}`,
        };
      }

      console.log(`[Recover] Wallet verified: ${wallet.address}`);

      // ── Debug: network info ────────────────────────────────────────────
      const rpcHost = new URL(rpcUrl).hostname;
      console.log(`[Recover] RPC host: ${rpcHost}, chainId: ${chainId}`);

      let netInfo: ethers.Network | null = null;
      try {
        netInfo = await provider.getNetwork();
        console.log(`[Recover] Provider network: chainId=${netInfo.chainId}, name=${netInfo.name}`);
      } catch (e: any) {
        console.log(`[Recover] Failed to get network: ${e?.message ?? e}`);
      }

      let latestBlock: number | null = null;
      try {
        latestBlock = await provider.getBlockNumber();
        console.log(`[Recover] Latest block: ${latestBlock}`);
      } catch (e: any) {
        console.log(`[Recover] Failed to get block number: ${e?.message ?? e}`);
      }

      // ── Check BNB balance for gas ──────────────────────────────────────
      const bnbBalance = await provider.getBalance(wallet.address);
      const fees = await getBscGasFees(provider, chainId);
      const gasLimit = 80000n;
      const estimatedGasCost = fees.gasPrice * gasLimit;

      console.log(
        `[Recover] BNB balance (raw wei): ${bnbBalance.toString()}`
      );
      console.log(
        `[Recover] BNB balance (formatted): ${ethers.formatEther(bnbBalance)}, estimated gas: ${ethers.formatEther(estimatedGasCost)}`
      );

      if (bnbBalance < estimatedGasCost) {
        return {
          success: false,
          sourceWalletAddress: wallet.address,
          destinationHotWallet: args.destinationHotWallet,
          error: `Insufficient BNB for gas. Available: ${ethers.formatEther(bnbBalance)}, needed: ${ethers.formatEther(estimatedGasCost)}`,
        };
      }

      // ── Check token balance ────────────────────────────────────────────
      const tokenContract = new ethers.Contract(
        args.tokenContractAddress,
        ERC20_ABI,
        wallet
      );

      let tokenBalance: bigint;
      let tokenDecimals: number;
      try {
        [tokenBalance, tokenDecimals] = await Promise.all([
          tokenContract.balanceOf(wallet.address),
          tokenContract.decimals(),
        ]);
      } catch {
        return {
          success: false,
          sourceWalletAddress: wallet.address,
          error: "Failed to read token contract. Verify tokenContractAddress is correct.",
        };
      }

      if (tokenBalance === 0n) {
        return {
          success: false,
          sourceWalletAddress: wallet.address,
          destinationHotWallet: args.destinationHotWallet,
          error: "Token balance is zero. Nothing to recover.",
        };
      }

      console.log(
        `[Recover] Token balance: ${ethers.formatUnits(tokenBalance, tokenDecimals)}`
      );

      // ── Transfer ───────────────────────────────────────────────────────
      console.log(`[Recover] Transferring to ${args.destinationHotWallet}...`);

      const tx = await tokenContract.transfer(
        args.destinationHotWallet,
        tokenBalance,
        {
          gasLimit,
          ...fees,
        }
      );

      console.log(`[Recover] Tx sent: ${tx.hash}, waiting for confirmation...`);

      const receipt = await waitForReceipt(provider, tx.hash);

      const formattedAmount = ethers.formatUnits(tokenBalance, tokenDecimals);
      console.log(`[Recover] ✅ Confirmed in block ${receipt.blockNumber}`);

      return {
        success: true,
        sourceWalletAddress: wallet.address,
        destinationHotWallet: args.destinationHotWallet,
        transactionHash: receipt.hash,
        transferredAmount: formattedAmount,
      };
    } catch (error: any) {
      console.error("[Recover] ❌ Error:", error?.reason ?? error?.message ?? error);
      return {
        success: false,
        error: error?.reason ?? error?.message ?? "Unknown error during token recovery",
      };
    } finally {
      if (decryptedKey) decryptedKey = null;
    }
  },
});
