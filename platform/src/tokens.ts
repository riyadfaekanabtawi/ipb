import { jwtVerify, SignJWT } from "jose";
import { ACCESS_TOKEN_TTL_SECONDS, config } from "./config.js";

// Short-lived access tokens (JWT HS256). Refresh tokens are opaque and live in `devices`.

export interface UserClaims {
  kind: "user";
  sub: string; // user id
  tid: string; // tenant id
  did: string; // device id
  role: string;
}

export interface AdminClaims {
  kind: "admin";
  sub: string; // platform admin id
}

export type Claims = UserClaims | AdminClaims;

const ISSUER = "trama-platform";

export async function signAccessToken(claims: Claims): Promise<string> {
  const { sub, ...rest } = claims;
  return new SignJWT({ ...rest })
    .setProtectedHeader({ alg: "HS256" })
    .setSubject(sub)
    .setIssuer(ISSUER)
    .setAudience(claims.kind)
    .setIssuedAt()
    .setExpirationTime(`${ACCESS_TOKEN_TTL_SECONDS}s`)
    .sign(config.jwtSecret);
}

export async function verifyAccessToken<K extends Claims["kind"]>(token: string, kind: K): Promise<Extract<Claims, { kind: K }>> {
  const { payload } = await jwtVerify(token, config.jwtSecret, { issuer: ISSUER, audience: kind, algorithms: ["HS256"] });
  if (payload.kind !== kind || typeof payload.sub !== "string") throw new Error("Wrong token kind");
  return { ...(payload as object), sub: payload.sub } as Extract<Claims, { kind: K }>;
}
