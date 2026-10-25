import { z } from "zod";
import { decryptJson, encryptJson } from "./crypto.js";
import { db, tx, type Tx } from "./db.js";
import { ApiError } from "./http.js";
import { msg, type Lang } from "./i18n.js";
import { encryptProfile, getTenant, licenceOf, tenantKey, userDto, type TenantRow, type UserRow } from "./tenants.js";
import type { UserClaims } from "./tokens.js";

// Sync protocol (shared by iOS, Android and the web app):
//
//   GET  /api/sync/pull?cursor=<version>&limit=<n>  → changes with version > cursor, ordered
//   POST /api/sync/push  { changes: Change[] }      → applied / rejected per change
//
// A Change carries one entity in the backup DTO format (`data`), its client `updatedAt` and a
// `deleted` flag. Conflicts resolve last-writer-wins on `updatedAt`; a losing push is rejected
// and the server copy is returned so the client can adopt it.

export const ENTITIES = ["plants", "clients", "suppliers", "contacts", "styles", "orders", "assignments", "reports", "projects", "users"] as const;
export type Entity = (typeof ENTITIES)[number];

export const changeSchema = z.object({
  entity: z.enum(ENTITIES),
  // Postgres returns uuids lowercase; normalize so the AAD used to encrypt matches the one used on pull
  // (iOS and the backup format send uppercase UUIDs).
  id: z.string().uuid().transform((value) => value.toLowerCase()),
  updatedAt: z.string().datetime({ offset: true }),
  deleted: z.boolean().optional().default(false),
  data: z.record(z.string(), z.unknown()).nullable().optional(),
});
export type Change = z.infer<typeof changeSchema>;

export const pushSchema = z.object({ changes: z.array(changeSchema).max(500) });

export interface ServerChange {
  entity: Entity;
  id: string;
  updatedAt: string;
  deleted: boolean;
  data: Record<string, unknown> | null;
  version: number;
}

export interface Rejection {
  entity: Entity;
  id: string;
  reason: "stale" | "forbidden" | "limit" | "conflict" | "invalid";
  message: string;
  server?: ServerChange;
}

const recordAad = (tenantId: string, entity: string, id: string) => `rec:${tenantId}:${entity}:${id}`;

// Roles (raw values shared with the apps; docs/DOMAIN.md rule 8–9).
const ADMIN = "Administrador";
const CUTS = "Gerente de Cortes";
const PLANT = "Gerente de Planta";
const SHIPPING = "Gerente de Envios";

/** Server-side mirror of the app permissions: who may write which entity. */
function canWrite(role: string, change: Change): boolean {
  if (role === ADMIN) return true;
  switch (change.entity) {
    case "orders":
    case "assignments":
      return role === CUTS;
    case "reports": {
      const kind = typeof change.data?.kindRaw === "string" ? change.data.kindRaw : null;
      if (change.deleted || !kind) return role === CUTS || role === PLANT || role === SHIPPING;
      return (kind === "corte" && role === CUTS) || (kind === "planta" && role === PLANT) || (kind === "envio" && role === SHIPPING);
    }
    default:
      return false; // catalogs and users: administrators only
  }
}

// Pull -----------------------------------------------------------------------------------

export async function pull(claims: UserClaims, cursor: number, limit: number) {
  const tenant = await getTenant(claims.tid);
  if (!tenant) throw new ApiError(404, "tenant_not_found", "tenantNotFound");
  const key = tenantKey(tenant);
  const take = Math.min(Math.max(limit, 1), 1000);

  const [records, users] = await Promise.all([
    db().query<{ entity: Entity; id: string; payload: Buffer | null; deleted: boolean; client_updated_at: Date; version: number }>(
      `SELECT entity, id, payload, deleted, client_updated_at, version FROM records
       WHERE tenant_id = $1 AND version > $2 ORDER BY version LIMIT $3`,
      [tenant.id, cursor, take + 1],
    ),
    db().query<UserRow>("SELECT * FROM users WHERE tenant_id = $1 AND version > $2 ORDER BY version LIMIT $3", [tenant.id, cursor, take + 1]),
  ]);

  const merged: ServerChange[] = [
    ...records.rows.map((r) => ({
      entity: r.entity,
      id: r.id,
      updatedAt: r.client_updated_at.toISOString(),
      deleted: r.deleted,
      data: r.deleted || !r.payload ? null : decryptJson<Record<string, unknown>>(key, r.payload, recordAad(tenant.id, r.entity, r.id)),
      version: r.version,
    })),
    ...users.rows.map((u) => ({
      entity: "users" as const,
      id: u.id,
      updatedAt: u.client_updated_at.toISOString(),
      deleted: u.deleted,
      data: u.deleted ? null : userDto(key, u),
      version: u.version,
    })),
  ].sort((a, b) => a.version - b.version);

  const page = merged.slice(0, take);
  return {
    changes: page,
    cursor: page.length ? page[page.length - 1].version : cursor,
    hasMore: merged.length > take,
    licence: licenceOf(tenant),
  };
}

// Push -----------------------------------------------------------------------------------

export async function push(claims: UserClaims, changes: Change[], lang: Lang = "es") {
  return tx(async (client) => {
    // Serialize pushes per company so limit checks and last-writer-wins are race-free.
    const { rows } = await client.query<TenantRow>("SELECT * FROM tenants WHERE id = $1 FOR UPDATE", [claims.tid]);
    const tenant = rows[0];
    if (!tenant) throw new ApiError(404, "tenant_not_found", "tenantNotFound");
    const licence = licenceOf(tenant);
    if (!licence.writable) {
      throw new ApiError(402, "licence_inactive", licence.status === "expired" ? "licenceExpiredReadOnly" : "licenceSuspended");
    }
    const key = tenantKey(tenant);
    const applied: { entity: Entity; id: string; version: number }[] = [];
    const rejected: Rejection[] = [];

    for (const change of changes) {
      const clientTime = clampFuture(new Date(change.updatedAt));
      if (!canWrite(claims.role, change)) {
        rejected.push({ entity: change.entity, id: change.id, reason: "forbidden", message: msg(lang, "roleForbidden") });
        continue;
      }
      if (!change.deleted && !change.data) {
        rejected.push({ entity: change.entity, id: change.id, reason: "invalid", message: msg(lang, "changeWithoutData") });
        continue;
      }
      const result =
        change.entity === "users"
          ? await applyUser(client, tenant, key, claims, change, clientTime, lang)
          : await applyRecord(client, tenant, key, claims, change, clientTime, lang);
      if ("version" in result) applied.push({ entity: change.entity, id: change.id, version: result.version });
      else rejected.push(result);
    }
    return { applied, rejected, licence };
  });
}

/** Devices with skewed clocks must not win every conflict forever. */
function clampFuture(date: Date): Date {
  const max = Date.now() + 5 * 60_000;
  return date.getTime() > max ? new Date(max) : date;
}

async function applyRecord(client: Tx, tenant: TenantRow, key: Buffer, claims: UserClaims, change: Change, clientTime: Date, lang: Lang): Promise<{ version: number } | Rejection> {
  const { rows } = await client.query<{ client_updated_at: Date; deleted: boolean; payload: Buffer | null; version: number }>(
    "SELECT client_updated_at, deleted, payload, version FROM records WHERE tenant_id = $1 AND entity = $2 AND id = $3",
    [tenant.id, change.entity, change.id],
  );
  const existing = rows[0];
  if (existing && existing.client_updated_at.getTime() > clientTime.getTime()) {
    return {
      entity: change.entity, id: change.id, reason: "stale" as const, message: msg(lang, "stale"),
      server: {
        entity: change.entity, id: change.id, updatedAt: existing.client_updated_at.toISOString(), deleted: existing.deleted, version: existing.version,
        data: existing.deleted || !existing.payload ? null : decryptJson<Record<string, unknown>>(key, existing.payload, recordAad(tenant.id, change.entity, change.id)),
      },
    };
  }
  if (change.entity === "plants" && !change.deleted && !existing) {
    const { rows: count } = await client.query<{ n: number }>(
      "SELECT count(*)::int AS n FROM records WHERE tenant_id = $1 AND entity = 'plants' AND NOT deleted", [tenant.id]);
    if (count[0].n >= tenant.max_plants) {
      return { entity: change.entity, id: change.id, reason: "limit" as const, message: msg(lang, "plantLimit", { count: tenant.max_plants }) };
    }
  }
  const payload = change.deleted ? null : encryptJson(key, { ...change.data, id: change.id }, recordAad(tenant.id, change.entity, change.id));
  const { rows: saved } = await client.query<{ version: number }>(
    `INSERT INTO records (tenant_id, entity, id, payload, deleted, client_updated_at, updated_by, updated_device)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
     ON CONFLICT (tenant_id, entity, id) DO UPDATE SET payload = EXCLUDED.payload, deleted = EXCLUDED.deleted,
       client_updated_at = EXCLUDED.client_updated_at, updated_by = EXCLUDED.updated_by, updated_device = EXCLUDED.updated_device,
       version = nextval('sync_version_seq')
     RETURNING version`,
    [tenant.id, change.entity, change.id, payload, change.deleted, clientTime, claims.sub, claims.did],
  );
  return { version: saved[0].version };
}

const userData = z.object({
  email: z.string().email().max(200),
  firstName: z.string().max(120).nullable().optional(),
  lastName: z.string().max(120).nullable().optional(),
  phone: z.string().max(40).nullable().optional(),
  avatarData: z.string().max(4_000_000).nullable().optional(),
  roleRaw: z.enum([ADMIN, CUTS, PLANT, SHIPPING]),
  isActive: z.boolean().optional().default(true),
  plantID: z.string().uuid().nullable().optional(),
  passwordHash: z.string().max(200).nullable().optional(),
  passwordSalt: z.string().max(200).nullable().optional(),
});

async function applyUser(client: Tx, tenant: TenantRow, key: Buffer, claims: UserClaims, change: Change, clientTime: Date, lang: Lang): Promise<{ version: number } | Rejection> {
  const { rows } = await client.query<UserRow>("SELECT * FROM users WHERE id = $1", [change.id]);
  const existing = rows[0];
  if (existing && existing.tenant_id !== tenant.id) {
    return { entity: change.entity, id: change.id, reason: "conflict" as const, message: msg(lang, "userOtherCompany") };
  }
  if (existing && existing.client_updated_at.getTime() > clientTime.getTime()) {
    return {
      entity: change.entity, id: change.id, reason: "stale" as const, message: msg(lang, "stale"),
      server: { entity: change.entity, id: change.id, updatedAt: existing.client_updated_at.toISOString(), deleted: existing.deleted, data: existing.deleted ? null : userDto(key, existing), version: existing.version },
    };
  }
  // An administrator can't delete/deactivate themselves (UserPolicy); the apps enforce the rest.
  if (change.id === claims.sub && (change.deleted || change.data?.isActive === false)) {
    return { entity: change.entity, id: change.id, reason: "forbidden" as const, message: msg(lang, "cannotRemoveSelf") };
  }
  if (change.deleted) {
    if (!existing) return { version: 0 };
    const { rows: saved } = await client.query<{ version: number }>(
      "UPDATE users SET deleted = true, is_active = false, client_updated_at = $2, version = nextval('sync_version_seq') WHERE id = $1 RETURNING version",
      [change.id, clientTime]);
    await client.query("UPDATE devices SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL", [change.id]);
    return { version: saved[0].version };
  }
  const parsed = userData.safeParse(change.data);
  if (!parsed.success) return { entity: change.entity, id: change.id, reason: "invalid" as const, message: msg(lang, "invalidUserData") };
  const u = parsed.data;
  const becomesActive = u.isActive && (!existing || !existing.is_active || existing.deleted);
  if (becomesActive) {
    const { rows: count } = await client.query<{ n: number }>("SELECT count(*)::int AS n FROM users WHERE tenant_id = $1 AND is_active AND NOT deleted", [tenant.id]);
    if (count[0].n >= tenant.max_users) {
      return { entity: change.entity, id: change.id, reason: "limit" as const, message: msg(lang, "userLimit", { count: tenant.max_users }) };
    }
  }
  const { rows: clash } = await client.query("SELECT 1 FROM users WHERE lower(email) = lower($1) AND id <> $2 AND NOT deleted", [u.email, change.id]);
  if (clash.length) return { entity: change.entity, id: change.id, reason: "conflict" as const, message: msg(lang, "emailTaken") };

  const profile = encryptProfile(key, tenant.id, change.id, { firstName: u.firstName, lastName: u.lastName, phone: u.phone, avatarData: u.avatarData });
  const { rows: saved } = await client.query<{ version: number }>(
    `INSERT INTO users (id, tenant_id, email, role, is_active, plant_id, password_hash, password_salt, profile_enc, client_updated_at)
     VALUES ($1, $2, lower($3), $4, $5, $6, $7, $8, $9, $10)
     ON CONFLICT (id) DO UPDATE SET email = EXCLUDED.email, role = EXCLUDED.role, is_active = EXCLUDED.is_active,
       plant_id = EXCLUDED.plant_id, profile_enc = EXCLUDED.profile_enc, deleted = false,
       password_hash = COALESCE(EXCLUDED.password_hash, users.password_hash),
       password_salt = COALESCE(EXCLUDED.password_salt, users.password_salt),
       client_updated_at = EXCLUDED.client_updated_at, version = nextval('sync_version_seq')
     RETURNING version`,
    [change.id, tenant.id, u.email, u.roleRaw, u.isActive, u.plantID ?? null, u.passwordHash ?? null, u.passwordSalt ?? null, profile, clientTime],
  );
  if (!u.isActive) await client.query("UPDATE devices SET revoked_at = now() WHERE user_id = $1 AND revoked_at IS NULL", [change.id]);
  return { version: saved[0].version };
}
