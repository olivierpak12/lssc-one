import { ethers } from "ethers";
import * as crypto from "crypto";

const ENCRYPTION_KEY = (() => {
  const key = process.env.ENCRYPTION_KEY;
  if (!key) throw new Error("ENCRYPTION_KEY must be set in environment variables (32 hex chars)");
  return key;
})();
const IV_LENGTH = 16;

/**
 * Encrypts a private key using AES-256-CBC
 */
export function encryptPrivateKey(privateKey: string) {
  const iv = crypto.randomBytes(IV_LENGTH);
  const cipher = crypto.createCipheriv("aes-256-cbc", Buffer.from(ENCRYPTION_KEY), iv);
  let encrypted = cipher.update(privateKey);
  encrypted = Buffer.concat([encrypted, cipher.final()]);
  return {
    iv: iv.toString("hex"),
    encryptedData: encrypted.toString("hex")
  };
}

/**
 * Decrypts a private key
 */
export function decryptPrivateKey(encryptedData: string, iv: string): string {
  const decipher = crypto.createDecipheriv(
    "aes-256-cbc",
    Buffer.from(ENCRYPTION_KEY),
    Buffer.from(iv, "hex")
  );
  let decrypted = decipher.update(Buffer.from(encryptedData, "hex"));
  decrypted = Buffer.concat([decrypted, decipher.final()]);
  return decrypted.toString();
}

/**
 * Generates a new EVM wallet
 */
export function generateWallet() {
  const wallet = ethers.Wallet.createRandom();
  const encrypted = encryptPrivateKey(wallet.privateKey);
  return {
    address: wallet.address,
    encryptedPrivateKey: encrypted.encryptedData,
    iv: encrypted.iv
  };
}
