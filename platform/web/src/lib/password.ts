// Password hashing compatible with the apps and the API (PasswordHasher / src/crypto.ts):
// PBKDF2-HMAC-SHA256, 120 000 iterations, 16-byte random salt, 32-byte key, all base64.

export const PBKDF2_ITERATIONS = 120_000;

const toBase64 = (bytes: Uint8Array) => {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
};

const fromBase64 = (b64: string) => Uint8Array.from(atob(b64), (c) => c.charCodeAt(0));

export function makeSalt(): string {
  return toBase64(crypto.getRandomValues(new Uint8Array(16)));
}

export async function hashPassword(password: string, salt: string): Promise<string> {
  // Same fallback as the apps: a non-base64 salt is used as UTF-8 bytes.
  let saltBytes: Uint8Array;
  try {
    saltBytes = fromBase64(salt);
  } catch {
    saltBytes = new TextEncoder().encode(salt);
  }
  const key = await crypto.subtle.importKey("raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits({ name: "PBKDF2", hash: "SHA-256", salt: saltBytes as BufferSource, iterations: PBKDF2_ITERATIONS }, key, 256);
  return toBase64(new Uint8Array(bits));
}
