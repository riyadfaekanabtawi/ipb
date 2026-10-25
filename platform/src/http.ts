import type { Context, MiddlewareHandler } from "hono";
import { HTTPException } from "hono/http-exception";
import type { ZodType } from "zod";
import { db } from "./db.js";
import { verifyAccessToken, type AdminClaims, type UserClaims } from "./tokens.js";

// Shared HTTP helpers: typed errors with Spanish messages, auth guards, body validation,
// and a small Postgres-backed rate limiter (works across serverless instances).

export class ApiError extends HTTPException {
  constructor(status: 400 | 401 | 402 | 403 | 404 | 409 | 410 | 413 | 422 | 429 | 500, readonly code: string, message: string) {
    super(status, { message });
  }
}

export type Env = { Variables: { user: UserClaims; admin: AdminClaims } };

function bearer(c: Context): string {
  const header = c.req.header("authorization") ?? "";
  const match = /^Bearer\s+(.+)$/i.exec(header);
  if (!match) throw new ApiError(401, "unauthenticated", "Inicia sesión para continuar.");
  return match[1];
}

export const requireUser: MiddlewareHandler<Env> = async (c, next) => {
  try {
    c.set("user", await verifyAccessToken(bearer(c), "user"));
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(401, "token_invalid", "Tu sesión expiró. Vuelve a iniciar sesión.");
  }
  await next();
};

export const requireAdmin: MiddlewareHandler<Env> = async (c, next) => {
  try {
    c.set("admin", await verifyAccessToken(bearer(c), "admin"));
  } catch (error) {
    if (error instanceof ApiError) throw error;
    throw new ApiError(401, "token_invalid", "Tu sesión expiró. Vuelve a iniciar sesión.");
  }
  await next();
};

export async function body<T>(c: Context, schema: ZodType<T>): Promise<T> {
  let raw: unknown;
  try {
    raw = await c.req.json();
  } catch {
    throw new ApiError(400, "invalid_json", "Solicitud inválida.");
  }
  const parsed = schema.safeParse(raw);
  if (!parsed.success) {
    const first = parsed.error.issues[0];
    throw new ApiError(422, "invalid_input", `Dato inválido: ${first?.path.join(".") || "solicitud"}.`);
  }
  return parsed.data;
}

/** Allows `max` attempts per `key` within `windowMinutes`; records this attempt. */
export async function rateLimit(key: string, max: number, windowMinutes: number) {
  const { rows } = await db().query<{ n: number }>(
    "SELECT count(*)::int AS n FROM login_attempts WHERE key = $1 AND at > now() - make_interval(mins => $2)",
    [key, windowMinutes],
  );
  if ((rows[0]?.n ?? 0) >= max) {
    throw new ApiError(429, "rate_limited", "Demasiados intentos. Espera unos minutos e inténtalo de nuevo.");
  }
  await db().query("INSERT INTO login_attempts (key) VALUES ($1)", [key]);
}

export function clientIp(c: Context): string {
  return (c.req.header("x-forwarded-for") ?? "").split(",")[0]?.trim() || "unknown";
}

export async function audit(actor: string, action: string, tenantId: string | null, detail: Record<string, unknown> = {}) {
  await db().query("INSERT INTO audit_log (actor, action, tenant_id, detail) VALUES ($1, $2, $3, $4)", [actor, action, tenantId, detail]);
}
