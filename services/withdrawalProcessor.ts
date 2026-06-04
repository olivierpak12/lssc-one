import { ethers } from "ethers";
import { ConvexHttpClient } from "convex/browser";
import * as dotenv from "dotenv";
import { api } from "../convex/_generated/api";

dotenv.config();

if (!process.env.CONVEX_URL) {
  console.error("FATAL: CONVEX_URL is not defined in .env");
  process.exit(1);
}

const convex = new ConvexHttpClient(process.env.CONVEX_URL!);

const USE_MAINNET = process.env.USE_MAINNET === "true";

const ALL_NETWORKS: any = {
  1: {
    name: "Ethereum Mainnet",
    rpc: process.env.ETH_MAINNET_RPC,
    tokens: {
      USDT: process.env.ETH_MAINNET_USDT,
      USDC: process.env.ETH_MAINNET_USDC
    },
    isMainnet: true,
  },
  137: {
    name: "Polygon Mainnet",
    rpc: process.env.POLYGON_MAINNET_RPC,
    tokens: {
      USDT: process.env.POLYGON_MAINNET_USDT,
      USDC: process.env.POLYGON_MAINNET_USDC
    },
    isMainnet: true,
  },
  11155111: {
    name: "Ethereum Sepolia",
    rpc: process.env.ETH_SEPOLIA_RPC,
    tokens: {
      USDT: process.env.ETH_SEPOLIA_USDT,
      USDC: process.env.ETH_SEPOLIA_USDC
    },
    isMainnet: false,
  },
  80002: {
    name: "Polygon Amoy",
    rpc: process.env.POLYGON_AMOY_RPC,
    tokens: {
      USDT: process.env.POLYGON_AMOY_USDT,
      USDC: process.env.POLYGON_AMOY_USDC
    },
    isMainnet: false,
  },
  97: {
    name: "BSC Testnet",
    rpc: process.env.BSC_TESTNET_RPC,
    tokens: {
      USDT: process.env.BSC_TESTNET_USDT,
      USDC: process.env.BSC_TESTNET_USDC
    },
    isMainnet: false,
  }
};

const NETWORKS: any = {};
for (const [chainId, net] of Object.entries(ALL_NETWORKS)) {
  const n = net as any;
  if (USE_MAINNET ? n.isMainnet : !n.isMainnet) {
    NETWORKS[chainId] = n;
  }
}

export async function processWithdrawals() {
  console.log("--- LSSC Global Multi-Token Withdrawal Processor Starting ---");
  console.log("Scanning for pending withdrawals every 15 seconds...");

  while (true) {
    try {
      const pending = await convex.query(api.admin.getPendingWithdrawals);
      if (pending.length > 0) {
        console.log(`Found ${pending.length} pending withdrawal(s)`);
      }
      for (const tx of pending) {
        await executeWithdrawal(tx);
      }
    } catch (e) {
      console.error("Processor Loop Error:", e);
    }
    await new Promise(r => setTimeout(r, 15000));
  }
}

async function executeWithdrawal(tx: any) {
  const network = NETWORKS[tx.chainId];
  
  if (!network) {
    console.error(`[${tx._id}] Error: Chain ID ${tx.chainId} not configured in NETWORKS.`);
    return;
  }

  if (!network.rpc) {
    console.error(`[${tx._id}] Error: RPC URL missing for ${network.name} (Chain ${tx.chainId}). Check .env`);
    return;
  }

  const tokenAddress = network.tokens[tx.token];
  if (!tokenAddress) {
    console.error(`[${tx._id}] Error: Unsupported token ${tx.token} on ${network.name}`);
    await convex.mutation(api.withdrawals.updateWithdrawalStatus, {
      withdrawalId: tx._id,
      status: "failed"
    });
    return;
  }

  try {
    const privateKey = process.env.HOT_WALLET_PRIVATE_KEY;
    if (!privateKey) {
        throw new Error("HOT_WALLET_PRIVATE_KEY is missing in .env");
    }

    const provider = new ethers.JsonRpcProvider(network.rpc);
    
    // Test connection
    try {
        await provider.getNetwork();
    } catch (connErr) {
        throw new Error(`Could not connect to RPC for ${network.name}: ${network.rpc}`);
    }

    const hotWallet = new ethers.Wallet(privateKey, provider);
    
    // Check Native Balance for Gas
    const nativeBalance = await provider.getBalance(hotWallet.address);
    if (nativeBalance === 0n) {
        throw new Error(`Hot wallet ${hotWallet.address} has 0 native funds for gas on ${network.name}. Please fund it.`);
    }

    const tokenContract = new ethers.Contract(tokenAddress, [
      "function transfer(address to, uint256 value) public returns (bool)",
      "function decimals() view returns (uint8)",
      "function balanceOf(address owner) view returns (uint256)"
    ], hotWallet);

    console.log(`[${tx._id}] Status: Moving to processing...`);
    await convex.mutation(api.withdrawals.updateWithdrawalStatus, {
      withdrawalId: tx._id,
      status: "processing"
    });

    const decimals: bigint = BigInt(await tokenContract.decimals());
    const balance: bigint = BigInt(await tokenContract.balanceOf(hotWallet.address));
    
    const amount6 = BigInt(tx.amount);
    const exponent = decimals - 6n;
    
    let amount: bigint;
    if (exponent >= 0n) {
        amount = amount6 * (10n ** exponent);
    } else {
        amount = amount6 / (10n ** (-exponent));
    }

    const readableAmount = ethers.formatUnits(amount, decimals);
    const readableBalance = ethers.formatUnits(balance, decimals);

    if (balance < amount) {
        throw new Error(`Insufficient Token Balance in Hot Wallet. Needs ${readableAmount} ${tx.token}, has ${readableBalance} ${tx.token}`);
    }

    console.log(`[${tx._id}] Executing: ${readableAmount} ${tx.token} to ${tx.toAddress} on ${network.name}`);

    const response = await tokenContract.transfer(tx.toAddress, amount);
    console.log(`[${tx._id}] Transaction Sent: ${response.hash}. Waiting for confirmation...`);
    
    const receipt = await response.wait();
    
    if (receipt && receipt.status === 1) {
      await convex.mutation(api.withdrawals.updateWithdrawalStatus, {
        withdrawalId: tx._id,
        status: "completed",
        txHash: response.hash
      });
      console.log(`[${tx._id}] Success! Hash: ${response.hash}`);
    } else {
      throw new Error("Transaction reverted on-chain");
    }
  } catch (error: any) {
    const errorMsg = error.message || "Unknown error";
    console.error(`[${tx._id}] Failed:`, errorMsg);
    
    // Don't mark as failed if it's a network/provider error, so it can be retried automatically
    const isRetryable = errorMsg.toLowerCase().includes("network") || 
                        errorMsg.toLowerCase().includes("timeout") || 
                        errorMsg.toLowerCase().includes("could not connect");

    if (!isRetryable) {
        await convex.mutation(api.withdrawals.updateWithdrawalStatus, {
            withdrawalId: tx._id,
            status: "failed"
        });
    } else {
        console.log(`[${tx._id}] Will retry in next loop (Network error).`);
    }
  }
}

processWithdrawals().catch(error => {
    console.error("FATAL: Processor crashed:", error);
});
