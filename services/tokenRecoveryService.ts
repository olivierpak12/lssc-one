import { ethers } from "ethers";
import * as crypto from "crypto";

// ─── Constants ────────────────────────────────────────────────────────────────

const BSC_CHAIN_ID = 56;
const BSC_TESTNET_CHAIN_ID = 97;

const ERC20_ABI = [
  "function balanceOf(address account) view returns (uint256)",
  "function transfer(address to, uint256 amount) returns (bool)",
  "function decimals() view returns (uint8)",
];

// ─── Types ────────────────────────────────────────────────────────────────────

export interface TokenRecoveryConfig {
  encryptionKey?: string;
  rpcUrl?: string;
  chainId?: number;
}

export interface RecoveryParams {
  encryptedPrivateKey: string;
  iv: string;
  expectedDepositAddress: string;
  destinationHotWallet: string;
  tokenContractAddress: string;
}

export interface RecoveryResult {
  success: boolean;
  sourceWalletAddress?: string;
  destinationHotWallet?: string;
  transactionHash?: string;
  transferredAmount?: string;
  tokenSymbol?: string;
  error?: string;
}

// ─── BSC Gas Fees ─────────────────────────────────────────────────────────────

interface BscGasFees {
  gasPrice: bigint;
}

async function getBscGasFees(
  provider: ethers.JsonRpcProvider,
  chainId: number
): Promise<BscGasFees> {
  const FALLBACK = {
    [BSC_CHAIN_ID]: ethers.parseUnits("3", "gwei"),
    [BSC_TESTNET_CHAIN_ID]: ethers.parseUnits("3", "gwei"),
  };

  const fallbackGasPrice = FALLBACK[chainId as keyof typeof FALLBACK] ?? ethers.parseUnits("3", "gwei");

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
  throw new Error(`Transaction not confirmed after ${timeoutMs / 1000}s — hash: ${txHash}`);
}

// ─── Token Recovery Service ───────────────────────────────────────────────────

export class TokenRecoveryService {
  private readonly encryptionKey: string;
  private readonly rpcUrl: string;
  private readonly chainId: number;

  constructor(config?: TokenRecoveryConfig) {
    const key =
      config?.encryptionKey ?? process.env.ENCRYPTION_KEY;
    if (!key) {
      throw new Error(
        "ENCRYPTION_KEY is required. Provide it via config or set the ENCRYPTION_KEY environment variable."
      );
    }
    this.encryptionKey = key;

    const isMainnet = process.env.USE_MAINNET === "true";
    this.chainId =
      config?.chainId ?? (isMainnet ? BSC_CHAIN_ID : BSC_TESTNET_CHAIN_ID);

    const rpcUrl =
      config?.rpcUrl ??
      (this.chainId === BSC_CHAIN_ID
        ? process.env.BSC_MAINNET_RPC
        : process.env.BSC_TESTNET_RPC);

    if (!rpcUrl) {
      throw new Error(
        `No RPC URL configured for BSC chain ID ${this.chainId}. ` +
        "Set BSC_MAINNET_RPC or BSC_TESTNET_RPC in environment variables."
      );
    }
    this.rpcUrl = rpcUrl;
  }

  // ── Public API ────────────────────────────────────────────────────────────

  async recoverTokens(params: RecoveryParams): Promise<RecoveryResult> {
    this.validateParams(params);

    let decryptedKey: string | null = null;
    try {
      // Step 1: Decrypt — never persisted, never logged
      decryptedKey = this.decryptPrivateKey(
        params.encryptedPrivateKey,
        params.iv
      );

      // Step 2: Connect to BSC
      const provider = new ethers.JsonRpcProvider(this.rpcUrl, this.chainId, {
        staticNetwork: true,
      });
      const wallet = new ethers.Wallet(decryptedKey, provider);

      // Step 3: Verify wallet address matches expected deposit address
      const derivedAddress = wallet.address.toLowerCase();
      const expectedAddress = params.expectedDepositAddress.toLowerCase();

      if (derivedAddress !== expectedAddress) {
        return {
          success: false,
          error: `Derived wallet address ${derivedAddress} does not match expected deposit address ${expectedAddress}`,
        };
      }

      // Step 4: Check BNB balance for gas
      const bnbBalance = await provider.getBalance(wallet.address);
      const fees = await getBscGasFees(provider, this.chainId);
      const gasLimit = 80000n;
      const estimatedGasCost = fees.gasPrice * gasLimit;

      if (bnbBalance < estimatedGasCost) {
        return {
          success: false,
          sourceWalletAddress: derivedAddress,
          error: `Insufficient BNB for gas. Available: ${ethers.formatEther(bnbBalance)}, needed: ${ethers.formatEther(estimatedGasCost)}`,
        };
      }

      // Step 5: Check token balance
      const tokenContract = new ethers.Contract(
        params.tokenContractAddress,
        ERC20_ABI,
        wallet
      );

      const [tokenBalance, tokenDecimals] = await Promise.all([
        tokenContract.balanceOf(wallet.address).catch(() => 0n),
        tokenContract.decimals().catch(() => 18),
      ]);

      if (tokenBalance === 0n || tokenBalance === undefined) {
        return {
          success: false,
          sourceWalletAddress: derivedAddress,
          error: "Token balance is zero. Nothing to recover.",
        };
      }

      // Step 6: Transfer entire token balance to hot wallet
      const tx = await tokenContract.transfer(
        params.destinationHotWallet,
        tokenBalance,
        {
          gasLimit,
          ...fees,
        }
      );

      // Step 7: Wait for confirmation
      const receipt = await waitForReceipt(provider, tx.hash);

      const formattedAmount = ethers.formatUnits(tokenBalance, tokenDecimals);

      return {
        success: true,
        sourceWalletAddress: derivedAddress,
        destinationHotWallet: params.destinationHotWallet,
        transactionHash: receipt.hash,
        transferredAmount: formattedAmount,
      };
    } catch (error: any) {
      return {
        success: false,
        error: error?.reason ?? error?.message ?? "Unknown error during token recovery",
      };
    } finally {
      // Security: clear in-memory key immediately
      if (decryptedKey) {
        decryptedKey = null;
      }
    }
  }

  // ── Private: Decryption ──────────────────────────────────────────────────

  private decryptPrivateKey(encryptedData: string, iv: string): string {
    try {
      const decipher = crypto.createDecipheriv(
        "aes-256-cbc",
        Buffer.from(this.encryptionKey),
        Buffer.from(iv, "hex")
      );
      let decrypted = decipher.update(Buffer.from(encryptedData, "hex"));
      decrypted = Buffer.concat([decrypted, decipher.final()]);
      const key = decrypted.toString();
      return key.startsWith("0x") ? key : "0x" + key;
    } catch (e) {
      throw new Error(
        "Private key decryption failed. Check that the encryptedPrivateKey, iv, and ENCRYPTION_KEY are correct."
      );
    }
  }

  // ── Private: Validation ──────────────────────────────────────────────────

  private validateParams(params: RecoveryParams): void {
    const errors: string[] = [];

    if (!params.encryptedPrivateKey || typeof params.encryptedPrivateKey !== "string") {
      errors.push("encryptedPrivateKey must be a non-empty string");
    }
    if (!params.iv || typeof params.iv !== "string") {
      errors.push("iv must be a non-empty string");
    }
    if (!params.expectedDepositAddress || !ethers.isAddress(params.expectedDepositAddress)) {
      errors.push("expectedDepositAddress must be a valid Ethereum address");
    }
    if (!params.destinationHotWallet || !ethers.isAddress(params.destinationHotWallet)) {
      errors.push("destinationHotWallet must be a valid Ethereum address");
    }
    if (!params.tokenContractAddress || !ethers.isAddress(params.tokenContractAddress)) {
      errors.push("tokenContractAddress must be a valid Ethereum address");
    }

    if (errors.length > 0) {
      throw new Error(`Validation failed: ${errors.join("; ")}`);
    }
  }
}
