import { ethers } from "ethers";

/**
 * Creates an ethers provider from a network record, using primary + fallback env vars.
 * Guards against undefined env vars — a common cause of CALL_EXCEPTION.
 */
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

/**
 * Wraps any ethers contract call with retry logic.
 * Retries up to 2 times with exponential backoff on CALL_EXCEPTION or
 * network errors. Does NOT retry on insufficient funds or bad address.
 */
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
