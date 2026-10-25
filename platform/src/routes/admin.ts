import { Hono } from "hono";
import { z } from "zod";
import { verifyPassword } from "../crypto.js";
import { db, tx } from "../db.js";
import { ApiError, audit, body, clientIp, rateLimit, requireAdmin, type Env } from "../http.js";
import { inviteEmail, sendMail } from "../mail.js";
import { PLAN_IDS, PLANS } from "../plans.js";
import { createTenant, encryptProfile, getTenant, licenceOf, tenantKey, userDto, type TenantRow, type UserRow } from "../tenants.js";
import { signAccessToken } from "../tokens.js";
import { createInvite } from "./auth.js";

// Admin portal API (platform owners only): companies, licences, devices, invitations.
export const admin = new Hono<Env>();

admin.post("/login", async (c) => {
  const input = await body(c, z.object({ email: z.string().email().max(200), password: z.string().min(1).max(200) }));
  await rateLimit(`admin-login:${input.email.toLowerCase()}`, 5, 15);
  await rateLimit(`admin-login-ip:${clientIp(c)}`, 20, 15);
  const { rows } = await db().query<{ id: string; name: string; password_hash: string | null; password_salt: string | null }>(
    "SELECT id, name, password_hash, password_salt FROM platform_admins WHERE lower(email) = lower($1)",
    [input.email],
  );
  const found = rows[0];
  if (!found || !verifyPassword(input.password, found.password_hash, found.password_salt)) {
    throw new ApiError(401, "bad_credentials", "Correo o contraseña incorrectos.");
  }
  await audit(`admin:${found.id}`, "admin.login", null);
  return c.json({ accessToken: await signAccessToken({ kind: "admin", sub: found.id }), admin: { id: found.id, name: found.name } });
});

admin.use("/*", async (c, next) => (c.req.path.endsWith("/admin/login") ? next() : requireAdmin(c, next)));

const tenantSummary = (t: TenantRow & { users?: number; devices?: number; last_seen?: Date | null }) => ({
  id: t.id,
  name: t.name,
  plan: t.plan,
  status: t.status,
  licence: licenceOf(t),
  limits: { maxUsers: t.max_users, maxDevices: t.max_devices, maxPlants: t.max_plants },
  usage: { users: t.users ?? 0, devices: t.devices ?? 0, lastSeenAt: t.last_seen?.toISOString() ?? null },
  contactEmail: t.contact_email,
  notes: t.notes,
  priceUsdMonthly: PLANS[t.plan].priceUsdMonthly,
  createdAt: t.created_at.toISOString(),
});

admin.get("/stats", async (c) => {
  const { rows } = await db().query<TenantRow>("SELECT * FROM tenants");
  const active = rows.filter((t) => licenceOf(t).status === "active");
  const byPlan = Object.fromEntries(PLAN_IDS.map((p) => [p, active.filter((t) => t.plan === p).length]));
  const mrr = active.reduce((sum, t) => sum + PLANS[t.plan].priceUsdMonthly, 0);
  const expiringSoon = active.filter((t) => t.expires_at.getTime() - Date.now() < 30 * 86_400_000).length;
  return c.json({ tenants: rows.length, active: active.length, byPlan, mrrUsd: mrr, expiringSoon });
});

admin.get("/tenants", async (c) => {
  const { rows } = await db().query<TenantRow & { users: number; devices: number; last_seen: Date | null }>(
    `SELECT t.*,
       (SELECT count(*)::int FROM users u WHERE u.tenant_id = t.id AND u.is_active AND NOT u.deleted) AS users,
       (SELECT count(*)::int FROM devices d WHERE d.tenant_id = t.id AND d.revoked_at IS NULL AND d.platform <> 'web' AND d.refresh_expires > now()) AS devices,
       (SELECT max(last_seen_at) FROM devices d WHERE d.tenant_id = t.id) AS last_seen
     FROM tenants t ORDER BY t.created_at DESC`,
  );
  return c.json({ tenants: rows.map(tenantSummary) });
});

const createSchema = z.object({
  name: z.string().trim().min(2).max(160),
  plan: z.enum(PLAN_IDS as [string, ...string[]]),
  months: z.number().int().min(1).max(60).default(12),
  contactEmail: z.string().email().max(200).optional(),
  notes: z.string().max(2000).optional(),
  maxUsers: z.number().int().min(1).max(100_000).optional(),
  maxDevices: z.number().int().min(0).max(100_000).optional(),
  maxPlants: z.number().int().min(1).max(100_000).optional(),
  admin: z.object({
    firstName: z.string().trim().min(1).max(120),
    lastName: z.string().trim().max(120).default(""),
    email: z.string().email().max(200),
  }),
});

admin.post("/tenants", async (c) => {
  const input = await body(c, createSchema);
  const actor = c.get("admin").sub;
  const result = await tx(async (client) => {
    const { rows: clash } = await client.query("SELECT 1 FROM users WHERE lower(email) = lower($1) AND NOT deleted", [input.admin.email]);
    if (clash.length) throw new ApiError(409, "email_taken", "Ya existe un usuario con ese correo.");
    const expiresAt = new Date();
    expiresAt.setMonth(expiresAt.getMonth() + input.months);
    const tenant = await createTenant(client, {
      name: input.name, plan: input.plan as TenantRow["plan"], expiresAt, contactEmail: input.contactEmail ?? input.admin.email,
      notes: input.notes, maxUsers: input.maxUsers, maxDevices: input.maxDevices, maxPlants: input.maxPlants,
    });
    const { rows: ids } = await client.query<{ id: string }>("SELECT gen_random_uuid() AS id");
    const userId = ids[0].id;
    const profile = encryptProfile(tenantKey(tenant), tenant.id, userId, { firstName: input.admin.firstName, lastName: input.admin.lastName });
    await client.query(
      `INSERT INTO users (id, tenant_id, email, role, is_active, profile_enc, client_updated_at) VALUES ($1, $2, lower($3), 'Administrador', true, $4, now())`,
      [userId, tenant.id, input.admin.email, profile],
    );
    const link = await createInvite("invite", { userId }, client);
    return { tenant, link };
  });
  await sendMail({
    ...inviteEmail("invite", input.admin.firstName, input.name, result.link, { plan: input.plan, expiresAt: result.tenant.expires_at, email: input.admin.email }),
    to: input.admin.email,
  });
  await audit(`admin:${actor}`, "tenant.create", result.tenant.id, { plan: input.plan, months: input.months });
  return c.json({ tenant: tenantSummary(result.tenant), inviteLink: result.link }, 201);
});

admin.get("/tenants/:id", async (c) => {
  const tenant = await getTenant(c.req.param("id"));
  if (!tenant) throw new ApiError(404, "not_found", "Empresa no encontrada.");
  const key = tenantKey(tenant);
  const [users, devices, audits] = await Promise.all([
    db().query<UserRow>("SELECT * FROM users WHERE tenant_id = $1 AND NOT deleted ORDER BY created_at", [tenant.id]),
    db().query<{ id: string; user_id: string; platform: string; name: string | null; created_at: Date; last_seen_at: Date; revoked_at: Date | null; refresh_expires: Date }>(
      "SELECT id, user_id, platform, name, created_at, last_seen_at, revoked_at, refresh_expires FROM devices WHERE tenant_id = $1 ORDER BY last_seen_at DESC", [tenant.id]),
    db().query("SELECT at, actor, action, detail FROM audit_log WHERE tenant_id = $1 ORDER BY at DESC LIMIT 50", [tenant.id]),
  ]);
  return c.json({
    tenant: tenantSummary({ ...tenant, users: users.rows.filter((u) => u.is_active).length }),
    users: users.rows.map((u) => {
      const dto = userDto(key, u, false);
      return { id: u.id, email: u.email, name: `${dto.firstName ?? ""} ${dto.lastName ?? ""}`.trim(), role: u.role, isActive: u.is_active, hasPassword: !!u.password_hash };
    }),
    devices: devices.rows.map((d) => ({
      id: d.id, userId: d.user_id, platform: d.platform, name: d.name, createdAt: d.created_at, lastSeenAt: d.last_seen_at,
      active: !d.revoked_at && d.refresh_expires.getTime() > Date.now(),
    })),
    audit: audits.rows,
  });
});

const patchSchema = z.object({
  name: z.string().trim().min(2).max(160).optional(),
  plan: z.enum(PLAN_IDS as [string, ...string[]]).optional(),
  status: z.enum(["active", "suspended"]).optional(),
  expiresAt: z.string().datetime({ offset: true }).optional(),
  extendMonths: z.number().int().min(1).max(60).optional(),
  maxUsers: z.number().int().min(1).max(100_000).optional(),
  maxDevices: z.number().int().min(0).max(100_000).optional(),
  maxPlants: z.number().int().min(1).max(100_000).optional(),
  contactEmail: z.string().email().max(200).nullable().optional(),
  notes: z.string().max(2000).nullable().optional(),
  applyPlanDefaults: z.boolean().optional(),
});

admin.patch("/tenants/:id", async (c) => {
  const input = await body(c, patchSchema);
  const id = c.req.param("id");
  const updated = await tx(async (client) => {
    const { rows } = await client.query<TenantRow>("SELECT * FROM tenants WHERE id = $1 FOR UPDATE", [id]);
    const t = rows[0];
    if (!t) throw new ApiError(404, "not_found", "Empresa no encontrada.");
    const plan = (input.plan ?? t.plan) as TenantRow["plan"];
    const defaults = input.applyPlanDefaults ? PLANS[plan] : null;
    let expires = input.expiresAt ? new Date(input.expiresAt) : t.expires_at;
    if (input.extendMonths) {
      const base = new Date(Math.max(expires.getTime(), Date.now()));
      base.setMonth(base.getMonth() + input.extendMonths);
      expires = base;
    }
    const { rows: saved } = await client.query<TenantRow>(
      `UPDATE tenants SET name = $2, plan = $3, status = $4, expires_at = $5, max_users = $6, max_devices = $7, max_plants = $8,
         contact_email = $9, notes = $10, updated_at = now() WHERE id = $1 RETURNING *`,
      [
        id, input.name ?? t.name, plan, input.status ?? t.status, expires,
        input.maxUsers ?? defaults?.maxUsers ?? t.max_users, input.maxDevices ?? defaults?.maxDevices ?? t.max_devices,
        input.maxPlants ?? defaults?.maxPlants ?? t.max_plants,
        input.contactEmail === undefined ? t.contact_email : input.contactEmail, input.notes === undefined ? t.notes : input.notes,
      ],
    );
    return saved[0];
  });
  await audit(`admin:${c.get("admin").sub}`, "tenant.update", id, input as Record<string, unknown>);
  return c.json({ tenant: tenantSummary(updated) });
});

admin.post("/tenants/:id/devices/:deviceId/revoke", async (c) => {
  const { rowCount } = await db().query("UPDATE devices SET revoked_at = now() WHERE id = $1 AND tenant_id = $2 AND revoked_at IS NULL", [
    c.req.param("deviceId"), c.req.param("id"),
  ]);
  if (!rowCount) throw new ApiError(404, "not_found", "Dispositivo no encontrado o ya liberado.");
  await audit(`admin:${c.get("admin").sub}`, "device.revoke", c.req.param("id"), { device: c.req.param("deviceId") });
  return c.json({ ok: true });
});

admin.post("/tenants/:id/users/:userId/invite", async (c) => {
  const tenant = await getTenant(c.req.param("id"));
  const { rows } = await db().query<UserRow>("SELECT * FROM users WHERE id = $1 AND tenant_id = $2 AND NOT deleted", [c.req.param("userId"), c.req.param("id")]);
  if (!tenant || !rows[0]) throw new ApiError(404, "not_found", "Usuario no encontrado.");
  const user = rows[0];
  const link = await createInvite(user.password_hash ? "reset" : "invite", { userId: user.id });
  const name = userDto(tenantKey(tenant), user, false).firstName ?? user.email;
  await sendMail({
    ...inviteEmail(user.password_hash ? "reset" : "invite", name, tenant.name, link, { plan: tenant.plan, expiresAt: tenant.expires_at, email: user.email }),
    to: user.email,
  });
  await audit(`admin:${c.get("admin").sub}`, "user.invite", tenant.id, { user: user.id });
  return c.json({ ok: true, inviteLink: link });
});
