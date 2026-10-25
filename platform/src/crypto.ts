import { createCipheriv, createDecipheriv, createHash, pbkdf2Sync, randomBytes, timingSafeEqual } from "node:crypto";

// Envelope encryption:
//   MASTER_KEY (env) ──wraps──▶ per-company DEK ──encrypts──▶ every record payload.
// Format of every ciphertext: 1 byte version | 12 byte IV | 16 byte GCM tag | ciphertext.
// The AAD binds a ciphertext to where it belongs (company/entity/id), so blobs can't be
// swapped between rows or companies without failing authentication.

const VERSION = 1;

export function encrypt(key: Buffer, plaintext: Buffer, aad: string): Buffer {
  const iv = randomBytes(12);
  const cipher = createCipheriv("aes-256-gcm", key, iv);
  cipher.setAAD(Buffer.from(aad, "utf8"));
  const body = Buffer.concat([cipher.update(plaintext), cipher.final()]);
  return Buffer.concat([Buffer.from([VERSION]), iv, cipher.getAuthTag(), body]);
}

export function decrypt(key: Buffer, blob: Buffer, aad: string): Buffer {
  if (blob.length < 29 || blob[0] !== VERSION) throw new Error("Unsupported ciphertext");
  const decipher = createDecipheriv("aes-256-gcm", key, blob.subarray(1, 13));
  decipher.setAAD(Buffer.from(aad, "utf8"));
  decipher.setAuthTag(blob.subarray(13, 29));
  return Buffer.concat([decipher.update(blob.subarray(29)), decipher.final()]);
}

export function encryptJson(key: Buffer, value: unknown, aad: string): Buffer {
  return encrypt(key, Buffer.from(JSON.stringify(value), "utf8"), aad);
}

export function decryptJson<T = unknown>(key: Buffer, blob: Buffer, aad: string): T {
  return JSON.parse(decrypt(key, blob, aad).toString("utf8")) as T;
}

/** New random data key for a company, wrapped with the master key. */
export function newWrappedDek(masterKey: Buffer, tenantId: string): Buffer {
  return encrypt(masterKey, randomBytes(32), `dek:${tenantId}`);
}

export function unwrapDek(masterKey: Buffer, wrapped: Buffer, tenantId: string): Buffer {
  return decrypt(masterKey, wrapped, `dek:${tenantId}`);
}

// Passwords: PBKDF2-HMAC-SHA256, 120k iterations, 16-byte salt, 32-byte key, base64.
// Identical to the iOS (CommonCrypto) and Android (javax.crypto) apps.
export const PBKDF2_ITERATIONS = 120_000;

export function makeSalt(): string {
  return randomBytes(16).toString("base64");
}

export function hashPassword(password: string, salt: string): string {
  return pbkdf2Sync(password, Buffer.from(salt, "base64"), PBKDF2_ITERATIONS, 32, "sha256").toString("base64");
}

export function verifyPassword(password: string, hash: string | null, salt: string | null): boolean {
  if (!hash || !salt) return false;
  const actual = Buffer.from(hashPassword(password, salt));
  const expected = Buffer.from(hash);
  return actual.length === expected.length && timingSafeEqual(actual, expected);
}

/** Opaque random token (refresh tokens, invite links). Only its SHA-256 is stored. */
export function newToken(): string {
  return randomBytes(32).toString("base64url");
}

export function sha256(value: string): string {
  return createHash("sha256").update(value).digest("hex");
}
