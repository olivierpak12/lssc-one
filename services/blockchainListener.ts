import { ethers } from "ethers";
import { ConvexHttpClient } from "convex/browser";
import * as dotenv from "dotenv";
import { api } from "../convex/_generated/api";
import { decryptPrivateKey } from "./walletService";

dotenv.config();

const convex = new ConvexHttpClient(process.env.CONVEX_URL!);

const USE_MAINNET = process.env.USE_MAINNET === "true";

const ALL_NETWORKS = [
  {
    name: "Ethereum Mainnet",
    chainId: 1,
    rpc: process.env.ETH_MAINNET_RPC!,
    tokens: [
      { symbol: "USDT", address: process.env.ETH_MAINNET_USDT!, decimals: 6 },
      { symbol: "USDC", address: process.env.ETH_MAINNET_USDC!, decimals: 6 }
    ],
    nativeSymbol: "ETH",
    isMainnet: true,
  },
  {
    name: "Polygon Mainnet",
    chainId: 137,
    rpc: process.env.POLYGON_MAINNET_RPC!,
    tokens: [
      { symbol: "USDT", address: process.env.POLYGON_MAINNET_USDT!, decimals: 6 },
      { symbol: "USDC", address: process.env.POLYGON_MAINNET_USDC!, decimals: 6 }
    ],
    nativeSymbol: "MATIC",
    isMainnet: true,
  },
  {
    name: "Ethereum Sepolia",
    chainId: 11155111,
    rpc: process.env.ETH_SEPOLIA_RPC!,
    tokens: [
      { symbol: "USDT", address: process.env.ETH_SEPOLIA_USDT!, decimals: 6 },
      { symbol: "USDC", address: process.env.ETH_SEPOLIA_USDC!, decimals: 6 }
    ],
    nativeSymbol: "ETH",
    isMainnet: false,
  },
  {
    name: "Polygon Amoy",
    chainId: 80002,
    rpc: process.env.POLYGON_AMOY_RPC!,
    tokens: [
      { symbol: "USDT", address: process.env.POLYGON_AMOY_USDT!, decimals: 6 },
      { symbol: "USDC", address: process.env.POLYGON_AMOY_USDC!, decimals: 6 }
    ],
    nativeSymbol: "MATIC",
    isMainnet: false,
  },
  {
    name: "BSC Testnet",
    chainId: 97,
    rpc: process.env.BSC_TESTNET_RPC!,
    tokens: [
      { symbol: "USDT", address: process.env.BSC_TESTNET_USDT!, decimals: 18 },
      { symbol: "USDC", address: process.env.BSC_TESTNET_USDC!, decimals: 18 }
    ],
    nativeSymbol: "BNB",
    isMainnet: false,
  }
];

const NETWORKS = ALL_NETWORKS.filter(n => USE_MAINNET ? n.isMainnet : !n.isMainnet);

const ERC20_ABI = [
  "event Transfer(address indexed from, address indexed to, uint256 value)",
  "function transfer(address to, uint256 value) public returns (bool)",
  "function balanceOf(address owner) view returns (uint256)"
];

const HOT_WALLET_ADDRESS = process.env.HOT_WALLET_ADDRESS!;

export async function startListeners() {
  console.log("--- LSSC Global Multi-Token Listener Started ---");
  
  for (const network of NETWORKS) {
    if (!network.rpc) {
        console.warn(`Skipping ${network.name}: RPC URL not configured.`);
        continue;
    }

    try {
      const provider = new ethers.JsonRpcProvider(network.rpc);
      
      for (const token of network.tokens) {
        if (!token.address) {
            console.warn(`Skipping ${token.symbol} on ${network.name}: Contract address not configured.`);
            continue;
        }
        const contract = new ethers.Contract(token.address, ERC20_ABI, provider);
        console.log(`Monitoring ${token.symbol} on ${network.name}...`);

        contract.on("Transfer", async (from, to, value, event) => {
          try {
            const wallet = await convex.query(api.wallets.getWalletByAddress, { address: to });
            if (!wallet) return;

            const normalizedAmount = token.decimals === 6 
              ? value 
              : (value / BigInt(10 ** (token.decimals - 6)));

            console.log(`[${network.name}] ${token.symbol} Deposit: ${ethers.formatUnits(normalizedAmount, 6)} to ${to}`);

            const depositId = await convex.mutation(api.deposits.recordDeposit, {
              userId: wallet.userId,
              txHash: event.log.transactionHash,
              chainId: network.chainId,
              network: network.name,
              amount: normalizedAmount.toString(),
              token: token.symbol
            });

            handleSweep(depositId, wallet, network, token, event.log.transactionHash);
          } catch (error) {
            console.error(`Error on ${network.name} ${token.symbol}:`, error);
          }
        });
      }
    } catch (e) {
      console.error(`Failed to connect to ${network.name}:`, e);
    }
  }
}

async function handleSweep(depositId: any, wallet: any, network: any, token: any, txHash: string) {
  try {
    const provider = new ethers.JsonRpcProvider(network.rpc);
    const privKey = decryptPrivateKey(wallet.encryptedPrivateKey, wallet.iv);
    const userWallet = new ethers.Wallet(privKey, provider);
    const tokenContract = new ethers.Contract(token.address, ERC20_ABI, userWallet);

    await provider.waitForTransaction(txHash, 1);
    await convex.mutation(api.deposits.updateStatus, { depositId, status: "confirmed" });

    const balance = await provider.getBalance(userWallet.address);
    const feeData = await provider.getFeeData();
    const gasPrice = feeData.gasPrice || ethers.parseUnits("20", "gwei");
    const requiredGas = gasPrice * 120000n;

    if (balance < requiredGas) {
      const funder = new ethers.Wallet(process.env.GAS_FUNDER_PRIVATE_KEY!, provider);
      const fundTx = await funder.sendTransaction({ to: userWallet.address, value: requiredGas * 2n });
      await fundTx.wait();
    }

    const tokenBalance = await tokenContract.balanceOf(userWallet.address);
    if (tokenBalance > 0n) {
      console.log(`Sweeping ${token.symbol} on ${network.name}...`);
      const sweepTx = await tokenContract.transfer(HOT_WALLET_ADDRESS, tokenBalance);
      await sweepTx.wait();

      await convex.mutation(api.deposits.updateStatus, {
        depositId,
        status: "swept",
        sweepTxHash: sweepTx.hash
      });
    }
  } catch (error) {
    console.error(`Sweep failed:`, error);
  }
}

startListeners();
