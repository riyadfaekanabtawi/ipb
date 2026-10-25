import { Hono } from "hono";
import { z } from "zod";
import { ACCESS_TOKEN_TTL_SECONDS, config, INVITE_TTL_HOURS, REFRESH_TTL_DAYS } from "../config.js";
import { hashPassword, makeSalt, newToken, sha256, verifyPassword } from "../crypto.js";
import { db, tx, type Tx } from "../db.js";
import { ApiError, body, clientIp, rateLimit, requestLang, requireUser, type Env } from "../http.js";
import { inviteEmail, sendMail } from "../mail.js";
import { PLANS } from "../plans.js";
import { findUserByEmail, getTenant, licenceOf, tenantKey, userDto, type TenantRow, type UserRow } from "../tenants.js";
import { signAccessToken } from "../tokens.js";

export const auth = new Hono<Env>();

const deviceSchema = z.object({
  id: z.string().uuid(),
  platform: z.enum(["ios", "android", "web"]),
  name: z.string().max(120).optional(),
});

const loginSchema = z.object({
  email: z.string().email().max(200),
  password: z.string().min(1).max(200),
  device: deviceSchema,
});

/** Issues tokens for a user on a device, enforcing plan rules and device seats. */
async function startSession(client: Tx, user: UserRow, tenant: TenantRow, device: z.infer<typeof deviceSchema>) {
  const native = device.platform !== "web";
  if (native && !PLANS[tenant.plan].nativeApps) {
    throw new ApiError(403, "plan_web_only", "planWebOnly");
  }
  if (native) {
    const { rows } = await client.query<{ n: number }>(
      `SELECT count(*)::int AS n FROM devices WHERE tenant_id = $1 AND platform <> 'web' AND revoked_at IS NULL
         AND refresh_expires > now() AND id <> $2`,
      [tenant.id, device.id],
    );
    if (rows[0].n >= tenant.max_devices) {
      throw new ApiError(403, "device_limit", "deviceLimit", { count: tenant.max_devices });
    }
  }
  const refreshToken = newToken();
  const ttlDays = native ? REFRESH_TTL_DAYS.app : REFRESH_TTL_DAYS.web;
  const { rows: existing } = await client.query<{ user_id: string; tenant_id: string }>("SELECT user_id, tenant_id FROM devices WHERE id = $1", [device.id]);
  if (existing[0] && (existing[0].tenant_id !== tenant.id)) {
    throw new ApiError(409, "device_conflict", "deviceConflict");
  }
  await client.query(
    `INSERT INTO devices (id, tenant_id, user_id, platform, name, refresh_hash, refresh_expires)
     VALUES ($1, $2, $3, $4, $5, $6, now() + make_interval(days => $7))
     ON CONFLICT (id) DO UPDATE SET user_id = EXCLUDED.user_id, platform = EXCLUDED.platform, name = EXCLUDED.name,
       refresh_hash = EXCLUDED.refresh_hash, refresh_expires = EXCLUDED.refresh_expires, revoked_at = NULL, last_seen_at = now()`,
    [device.id, tenant.id, user.id, device.platform, device.name ?? null, sha256(refreshToken), ttlDays],
  );
  const accessToken = await signAccessToken({ kind: "user", sub: user.id, tid: tenant.id, did: device.id, role: user.role });
  const key = tenantKey(tenant);
  return {
    accessToken,
    refreshToken,
    expiresIn: ACCESS_TOKEN_TTL_SECONDS,
    user: userDto(key, user),
    tenant: { id: tenant.id, name: tenant.name, plan: tenant.plan, maxUsers: tenant.max_users, maxDevices: tenant.max_devices, maxPlants: tenant.max_plants },
    licence: licenceOf(tenant),
  };
}

auth.post("/login", async (c) => {
  const input = await body(c, loginSchema);
  await rateLimit(`login:${input.email.toLowerCase()}`, 10, 15);
  await rateLimit(`login-ip:${clientIp(c)}`, 50, 15);
  return c.json(
    await tx(async (client) => {
      const user = await findUserByEmail(input.email, client);
      if (!user || !verifyPassword(input.password, user.password_hash, user.password_salt)) {
        throw new ApiError(401, "bad_credentials", "badCredentials");
      }
      if (!user.is_active) throw new ApiError(403, "user_inactive", "userInactive");
      const tenant = await getTenant(user.tenant_id, client);
      if (!tenant) throw new ApiError(404, "tenant_not_found", "tenantNotFound");
      if (tenant.status === "suspended") throw new ApiError(403, "licence_suspended", "licenceSuspendedLogin");
      return startSession(client, user, tenant, input.device);
    }),
  );
});

auth.post("/refresh", async (c) => {
  const { refreshToken } = await body(c, z.object({ refreshToken: z.string().min(20).max(200) }));
  return c.json(
    await tx(async (client) => {
      const { rows } = await client.query<{ id: string; user_id: string; tenant_id: string; platform: "ios" | "android" | "web"; name: string | null }>(
        "SELECT id, user_id, tenant_id, platform, name FROM devices WHERE refresh_hash = $1 AND revoked_at IS NULL AND refresh_expires > now() FOR UPDATE",
        [sha256(refreshToken)],
      );
      const device = rows[0];
      if (!device) throw new ApiError(401, "refresh_invalid", "sessionExpired");
      const { rows: users } = await client.query<UserRow>("SELECT * FROM users WHERE id = $1 AND NOT deleted AND is_active", [device.user_id]);
      const tenant = await getTenant(device.tenant_id, client);
      if (!users[0] || !tenant || tenant.status === "suspended") throw new ApiError(401, "refresh_invalid", "sessionExpired");
      return startSession(client, users[0], tenant, { id: device.id, platform: device.platform, name: device.name ?? undefined });
    }),
  );
});

auth.post("/logout", requireUser, async (c) => {
  await db().query("UPDATE devices SET revoked_at = now() WHERE id = $1 AND user_id = $2", [c.get("user").did, c.get("user").sub]);
  return c.json({ ok: true });
});

auth.get("/me", requireUser, async (c) => {
  const claims = c.get("user");
  const tenant = await getTenant(claims.tid);
  const { rows } = await db().query<UserRow>("SELECT * FROM users WHERE id = $1 AND NOT deleted", [claims.sub]);
  if (!tenant || !rows[0]) throw new ApiError(401, "token_invalid", "sessionExpired");
  await db().query("UPDATE devices SET last_seen_at = now() WHERE id = $1", [claims.did]);
  return c.json({ user: userDto(tenantKey(tenant), rows[0], false), tenant: { id: tenant.id, name: tenant.name, plan: tenant.plan }, licence: licenceOf(tenant) });
});

// Invitations and password resets ------------------------------------------------------

auth.post("/accept-invite", async (c) => {
  const input = await body(c, z.object({ token: z.string().min(20).max(200), password: z.string().min(8).max(200) }));
  await rateLimit(`invite-ip:${clientIp(c)}`, 20, 15);
  await tx(async (client) => {
    const { rows } = await client.query<{ kind: string; user_id: string | null; admin_id: string | null }>(
      "UPDATE invites SET used_at = now() WHERE token_hash = $1 AND used_at IS NULL AND expires_at > now() RETURNING kind, user_id, admin_id",
      [sha256(input.token)],
    );
    const invite = rows[0];
    if (!invite) throw new ApiError(410, "invite_invalid", "inviteInvalid");
    const salt = makeSalt();
    const hash = hashPassword(input.password, salt);
    if (invite.kind === "platform_admin") {
      await client.query("UPDATE platform_admins SET password_hash = $2, password_salt = $3 WHERE id = $1", [invite.admin_id, hash, salt]);
    } else {
      // Bump the sync version so devices receive the new hash (offline login keeps working).
      await client.query(
        "UPDATE users SET password_hash = $2, password_salt = $3, client_updated_at = now(), version = nextval('sync_version_seq') WHERE id = $1",
        [invite.user_id, hash, salt],
      );
      if (invite.kind === "reset") await client.query("UPDATE devices SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL", [invite.user_id]);
    }
  });
  return c.json({ ok: true });
});

auth.post("/forgot", async (c) => {
  const { email } = await body(c, z.object({ email: z.string().email().max(200) }));
  await rateLimit(`forgot:${email.toLowerCase()}`, 3, 60);
  const user = await findUserByEmail(email);
  // Same answer whether or not the account exists (no account enumeration).
  if (user?.is_active) {
    const tenant = await getTenant(user.tenant_id);
    const name = tenant ? (userDto(tenantKey(tenant), user, false).firstName ?? user.email) : user.email;
    const link = await createInvite("reset", { userId: user.id });
    // The reset email follows the language of whoever asked for it.
    await sendMail({ ...inviteEmail("reset", name, tenant?.name ?? null, link, {}, requestLang(c)), to: user.email });
  }
  return c.json({ ok: true });
});

export async function createInvite(kind: "invite" | "reset" | "platform_admin", ids: { userId?: string; adminId?: string }, client: Pick<Tx, "query"> = db()) {
  const token = newToken();
  await client.query(
    "INSERT INTO invites (token_hash, kind, user_id, admin_id, expires_at) VALUES ($1, $2, $3, $4, now() + make_interval(hours => $5))",
    [sha256(token), kind, ids.userId ?? null, ids.adminId ?? null, INVITE_TTL_HOURS],
  );
  const path = kind === "platform_admin" ? "admin/activar" : kind === "reset" ? "restablecer" : "activar";
  return `${config.appUrl}/${path}?token=${token}`;
}
