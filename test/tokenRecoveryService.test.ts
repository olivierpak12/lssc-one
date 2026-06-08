/**
 * Unit tests for TokenRecoveryService
 *
 * Setup:
 *   npm install --save-dev vitest
 *   Add "test": "vitest run" to package.json scripts
 *
 * Run:
 *   npx vitest run test/tokenRecoveryService.test.ts
 *
 * These tests use a mock provider and do NOT touch the real blockchain.
 */

import { describe, it, expect, beforeEach, afterEach } from "vitest";
import { randomBytes, createCipheriv } from "crypto";
import { TokenRecoveryService } from "../services/tokenRecoveryService";

describe("TokenRecoveryService — Decryption", () => {
  const ENCRYPTION_KEY = "faaad9e415b31f81e66bf70d85e82230"; // matches .env
  const TEST_PRIVATE_KEY = "0x0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef";

  function encryptForTest(key: string, plaintext: string) {
    const iv = randomBytes(16);
    const cipher = createCipheriv("aes-256-cbc", Buffer.from(key), iv);
    let enc = cipher.update(plaintext);
    enc = Buffer.concat([enc, cipher.final()]);
    return { iv: iv.toString("hex"), encryptedData: enc.toString("hex") };
  }

  it("should decrypt a correctly encrypted private key", () => {
    const { iv, encryptedData } = encryptForTest(ENCRYPTION_KEY, TEST_PRIVATE_KEY);

    // Use the service's decryption
    const service = new TokenRecoveryService({ encryptionKey: ENCRYPTION_KEY, rpcUrl: "http://localhost:8545" });
    const decrypted = (service as any).decryptPrivateKey(encryptedData, iv);

    expect(decrypted).toBe(TEST_PRIVATE_KEY);
  });

  it("should add 0x prefix if missing", () => {
    const withoutPrefix = TEST_PRIVATE_KEY.replace("0x", "");
    const { iv, encryptedData } = encryptForTest(ENCRYPTION_KEY, withoutPrefix);

    const service = new TokenRecoveryService({ encryptionKey: ENCRYPTION_KEY, rpcUrl: "http://localhost:8545" });
    const decrypted = (service as any).decryptPrivateKey(encryptedData, iv);

    expect(decrypted).toBe("0x" + withoutPrefix);
  });

  it("should throw on wrong encryption key", () => {
    const { iv, encryptedData } = encryptForTest(ENCRYPTION_KEY, TEST_PRIVATE_KEY);
    const wrongKey = "aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa";

    const service = new TokenRecoveryService({ encryptionKey: wrongKey, rpcUrl: "http://localhost:8545" });

    expect(() => (service as any).decryptPrivateKey(encryptedData, iv)).toThrow();
  });

  it("should throw on invalid hex data", () => {
    const service = new TokenRecoveryService({ encryptionKey: ENCRYPTION_KEY, rpcUrl: "http://localhost:8545" });

    expect(() => (service as any).decryptPrivateKey("zzzz", "00000000000000000000000000000000")).toThrow();
  });
});

describe("TokenRecoveryService — Input Validation", () => {
  const VALID_ADDRESS = "0x3dE5610ebD28C279A66330659016C072D000c4e4";

  it("should accept valid parameters", () => {
    const service = new TokenRecoveryService({ encryptionKey: "test-key-1234-test-key-1234", rpcUrl: "http://localhost:8545" });
    expect(() =>
      (service as any).validateParams({
        encryptedPrivateKey: "abcd1234",
        iv: "00112233445566778899aabbccddeeff",
        expectedDepositAddress: VALID_ADDRESS,
        destinationHotWallet: VALID_ADDRESS,
        tokenContractAddress: VALID_ADDRESS,
      })
    ).not.toThrow();
  });

  it("should reject invalid addresses", () => {
    const service = new TokenRecoveryService({ encryptionKey: "test-key-1234-test-key-1234", rpcUrl: "http://localhost:8545" });
    expect(() =>
      (service as any).validateParams({
        encryptedPrivateKey: "abcd1234",
        iv: "00112233445566778899aabbccddeeff",
        expectedDepositAddress: "not-an-address",
        destinationHotWallet: VALID_ADDRESS,
        tokenContractAddress: VALID_ADDRESS,
      })
    ).toThrow();
  });

  it("should reject missing encryptedPrivateKey", () => {
    const service = new TokenRecoveryService({ encryptionKey: "test-key-1234-test-key-1234", rpcUrl: "http://localhost:8545" });
    expect(() =>
      (service as any).validateParams({
        encryptedPrivateKey: "",
        iv: "00112233445566778899aabbccddeeff",
        expectedDepositAddress: VALID_ADDRESS,
        destinationHotWallet: VALID_ADDRESS,
        tokenContractAddress: VALID_ADDRESS,
      })
    ).toThrow();
  });

  it("should reject missing iv", () => {
    const service = new TokenRecoveryService({ encryptionKey: "test-key-1234-test-key-1234", rpcUrl: "http://localhost:8545" });
    expect(() =>
      (service as any).validateParams({
        encryptedPrivateKey: "abcd1234",
        iv: "",
        expectedDepositAddress: VALID_ADDRESS,
        destinationHotWallet: VALID_ADDRESS,
        tokenContractAddress: VALID_ADDRESS,
      })
    ).toThrow();
  });
});

describe("TokenRecoveryService — Constructor Config", () => {
  const OLD_ENV = process.env;

  beforeEach(() => {
    process.env = { ...OLD_ENV };
    delete process.env.ENCRYPTION_KEY;
    delete process.env.BSC_MAINNET_RPC;
    delete process.env.BSC_TESTNET_RPC;
    delete process.env.USE_MAINNET;
  });

  afterEach(() => {
    process.env = OLD_ENV;
  });

  it("should throw if no encryption key provided", () => {
    expect(() => new TokenRecoveryService()).toThrow("ENCRYPTION_KEY");
  });

  it("should throw if no RPC URL available", () => {
    process.env.ENCRYPTION_KEY = "aaaabbbbccccddddeeeeffffgggghhhh";
    process.env.USE_MAINNET = "false";
    expect(() => new TokenRecoveryService()).toThrow("RPC URL");
  });

  it("should use config values when provided", () => {
    const service = new TokenRecoveryService({
      encryptionKey: "custom-key-1234-custom-key-1234",
      rpcUrl: "https://custom-rpc.example.com",
      chainId: 56,
    });
    expect(service).toBeDefined();
    expect((service as any).encryptionKey).toBe("custom-key-1234-custom-key-1234");
    expect((service as any).rpcUrl).toBe("https://custom-rpc.example.com");
    expect((service as any).chainId).toBe(56);
  });

  it("should resolve env vars when no config provided", () => {
    process.env.ENCRYPTION_KEY = "env-key-12345-env-key-12345";
    process.env.BSC_TESTNET_RPC = "https://bsc-testnet.example.com";
    process.env.USE_MAINNET = "false";

    const service = new TokenRecoveryService();
    expect((service as any).encryptionKey).toBe("env-key-12345-env-key-12345");
    expect((service as any).rpcUrl).toBe("https://bsc-testnet.example.com");
    expect((service as any).chainId).toBe(97);
  });
});
