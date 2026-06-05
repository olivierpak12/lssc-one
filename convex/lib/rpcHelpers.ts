import { ethers } from "ethers";

// ─── Provider ────────────────────────────────────────────────────────────────

export function getProvider(network: {
  rpcUrl: string;
  defaultRpc?: string;
  name: string;
}): ethers.JsonRpcProvider {
  const primary = process.env[network.rpcUrl];
  const fallback = network.defaultRpc ? process.env[network.defaultRpc] : undefined;
  const url = primary || fallback;

  if (!url) {
    const envVars = network.defaultRpc
      ? `${network.rpcUrl} or ${network.defaultRpc}`
      : network.rpcUrl;
    throw new Error(
      `No RPC URL configured for network "${network.name}". ` +
      `Set ${envVars} in Convex environment variables.`
    );
  }

  return new ethers.JsonRpcProvider(url);
}

// ─── Multi-chain gas fees ─────────────────────────────────────────────────────
//
// Each chain has different gas quirks:
//
// POLYGON (chainId 137)
//   - Non-standard EIP-1559. ethers defaults maxPriorityFeePerGas to 1.5 gwei
//     but Polygon requires a MINIMUM of 25 gwei or the tx sits in mempool forever.
//   - Must fetch from Polygon gas station oracle.
//
// BSC (chainId 56)
//   - Does NOT support EIP-1559 (Type 2 txs). BSC uses legacy gasPrice only.
//   - gasPrice is typically 1–3 gwei on BSC mainnet. Very cheap and fast.
//   - Using maxFeePerGas on BSC will throw "transaction type not supported".
//
// All other chains
//   - Fall back to provider.getFeeData() with a 30% buffer on gasPrice.

export interface ChainGasFees {
  // EIP-1559 chains (Polygon)
  maxFeePerGas?: bigint;
  maxPriorityFeePerGas?: bigint;
  // Legacy chains (BSC)
  gasPrice?: bigint;
}

export async function getGasFees(
  chainId: number,
  provider: ethers.JsonRpcProvider
): Promise<ChainGasFees> {
  switch (chainId) {
    // ── Polygon PoS ──────────────────────────────────────────────────────────
    case 137: {
      const FALLBACK_PRIORITY = ethers.parseUnits("50", "gwei");
      const FALLBACK_MAX = ethers.parseUnits("300", "gwei");

      try {
        const res = await fetch("https://gasstation.polygon.technology/v2");
        if (!res.ok) throw new Error(`Gas station ${res.status}`);
        const data = await res.json();

        const priorityGwei = Math.ceil(data.fast.maxPriorityFee * 1.2);
        const maxGwei = Math.ceil(data.fast.maxFee * 1.2);

        const maxPriorityFeePerGas = ethers.parseUnits(String(priorityGwei), "gwei");
        const maxFeePerGas = ethers.parseUnits(String(maxGwei), "gwei");

        console.log(`[Gas] Polygon: priority=${priorityGwei} gwei, maxFee=${maxGwei} gwei`);
        return { maxFeePerGas, maxPriorityFeePerGas };
      } catch (err) {
        console.warn(`[Gas] Polygon gas station failed, using fallback: ${err}`);
        return { maxFeePerGas: FALLBACK_MAX, maxPriorityFeePerGas: FALLBACK_PRIORITY };
      }
    }

    // ── BNB Smart Chain ──────────────────────────────────────────────────────
    // BSC is a legacy (pre-EIP-1559) chain. Must use gasPrice, NOT maxFeePerGas.
    // Using EIP-1559 fields on BSC throws "transaction type not supported".
    case 56: {
      const FALLBACK_GAS_PRICE = ethers.parseUnits("3", "gwei"); // BSC safe fallback

      try {
        const feeData = await provider.getFeeData();
        const base = feeData.gasPrice ?? FALLBACK_GAS_PRICE;
        // +20% buffer — BSC fees are stable but can tick up slightly
        const gasPrice = (base * 120n) / 100n;

        console.log(`[Gas] BSC: gasPrice=${ethers.formatUnits(gasPrice, "gwei")} gwei`);
        return { gasPrice };
      } catch (err) {
        console.warn(`[Gas] BSC fee fetch failed, using fallback: ${err}`);
        return { gasPrice: FALLBACK_GAS_PRICE };
      }
    }

    // ── Default: EIP-1559 with buffer ────────────────────────────────────────
    default: {
      try {
        const feeData = await provider.getFeeData();
        if (feeData.maxFeePerGas && feeData.maxPriorityFeePerGas) {
          return {
            maxFeePerGas: (feeData.maxFeePerGas * 130n) / 100n,
            maxPriorityFeePerGas: (feeData.maxPriorityFeePerGas * 130n) / 100n,
          };
        }
        // Chain doesn't support EIP-1559 — fall back to legacy gasPrice
        const base = feeData.gasPrice ?? ethers.parseUnits("20", "gwei");
        return { gasPrice: (base * 130n) / 100n };
      } catch (err) {
        console.warn(`[Gas] Default fee fetch failed: ${err}`);
        return { gasPrice: ethers.parseUnits("20", "gwei") };
      }
    }
  }
}

// ─── Retry ───────────────────────────────────────────────────────────────────

export async function withRetry<T>(
  fn: () => Promise<T>,
  label: string,
  retries = 2
): Promise<T> {
  for (let attempt = 0; attempt <= retries; attempt++) {
    try {
      return await fn();
    } catch (err: any) {
      const isRetryable =
        err?.code === "CALL_EXCEPTION" ||
        err?.code === "NETWORK_ERROR" ||
        err?.code === "TIMEOUT" ||
        err?.message?.includes("missing revert data");

      const isLastAttempt = attempt === retries;

      if (!isRetryable || isLastAttempt) {
        console.error(`[${label}] Failed after ${attempt + 1} attempt(s):`, err?.message);
        throw err;
      }

      const waitMs = 1000 * Math.pow(2, attempt); // 1s, 2s
      console.warn(`[${label}] Attempt ${attempt + 1} failed, retrying in ${waitMs}ms...`);
      await new Promise((r) => setTimeout(r, waitMs));
    }
  }
  throw new Error("unreachable");
}