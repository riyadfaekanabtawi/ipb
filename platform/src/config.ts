// Runtime configuration from environment variables. Read lazily so tests can set them.

function required(name: string): string {
  const value = process.env[name];
  if (!value) throw new Error(`Missing environment variable ${name}`);
  return value;
}

export const config = {
  /** Postgres connection string (Neon pooled URL in production). */
  get databaseUrl() {
    return required("DATABASE_URL");
  },
  /** 32-byte base64 key that wraps every company data key. Never rotate without re-wrapping. */
  get masterKey(): Buffer {
    const key = Buffer.from(required("MASTER_KEY"), "base64");
    if (key.length !== 32) throw new Error("MASTER_KEY must be 32 bytes (base64)");
    return key;
  },
  /** HMAC secret for access tokens (at least 32 bytes). */
  get jwtSecret(): Uint8Array {
    const secret = required("JWT_SECRET");
    if (secret.length < 32) throw new Error("JWT_SECRET must be at least 32 characters");
    return new TextEncoder().encode(secret);
  },
  /** Public URL of the web app (links in emails). */
  get appUrl() {
    return (process.env.APP_URL ?? "https://trama-platform.vercel.app").replace(/\/$/, "");
  },
  get gmailUser() {
    return process.env.GMAIL_USER;
  },
  get gmailPassword() {
    return process.env.GMAIL_APP_PASSWORD;
  },
};

export const ACCESS_TOKEN_TTL_SECONDS = 15 * 60;
export const REFRESH_TTL_DAYS = { app: 90, web: 7 } as const;
export const INVITE_TTL_HOURS = 72;
