import { config } from "./config.js";
import { decryptJson, encryptJson, newWrappedDek, unwrapDek } from "./crypto.js";
import { db, type Tx } from "./db.js";
import { licenceState, PLANS, type Plan } from "./plans.js";

export interface TenantRow {
  id: string;
  name: string;
  plan: Plan;
  status: string;
  max_users: number;
  max_devices: number;
  max_plants: number;
  expires_at: Date;
  dek_wrapped: Buffer;
  contact_email: string | null;
  notes: string | null;
  created_at: Date;
  updated_at: Date;
}

// Unwrapped data keys cached per serverless instance (keys never leave memory or get logged).
const dekCache = new Map<string, Buffer>();

export function tenantKey(tenant: Pick<TenantRow, "id" | "dek_wrapped">): Buffer {
  let key = dekCache.get(tenant.id);
  if (!key) {
    key = unwrapDek(config.masterKey, tenant.dek_wrapped, tenant.id);
    dekCache.set(tenant.id, key);
  }
  return key;
}

export async function getTenant(id: string, client: Pick<Tx, "query"> = db()): Promise<TenantRow | undefined> {
  const { rows } = await client.query<TenantRow>("SELECT * FROM tenants WHERE id = $1", [id]);
  return rows[0];
}

export function licenceOf(tenant: TenantRow) {
  return licenceState({ plan: tenant.plan, status: tenant.status, expires_at: tenant.expires_at });
}

export interface NewTenant {
  name: string;
  plan: Plan;
  expiresAt: Date;
  contactEmail?: string | null;
  notes?: string | null;
  maxUsers?: number;
  maxDevices?: number;
  maxPlants?: number;
}

export async function createTenant(client: Tx, input: NewTenant): Promise<TenantRow> {
  const limits = PLANS[input.plan];
  const { rows: ids } = await client.query<{ id: string }>("SELECT gen_random_uuid() AS id");
  const id = ids[0].id;
  const { rows } = await client.query<TenantRow>(
    `INSERT INTO tenants (id, name, plan, max_users, max_devices, max_plants, expires_at, dek_wrapped, contact_email, notes)
     VALUES ($1, $2, $3, $4, $5, $6, $7, $8, $9, $10) RETURNING *`,
    [
      id, input.name.trim(), input.plan, input.maxUsers ?? limits.maxUsers, input.maxDevices ?? limits.maxDevices,
      input.maxPlants ?? limits.maxPlants, input.expiresAt, newWrappedDek(config.masterKey, id),
      input.contactEmail ?? null, input.notes ?? null,
    ],
  );
  return rows[0];
}

// Users ----------------------------------------------------------------------------------

export interface UserRow {
  id: string;
  tenant_id: string;
  email: string;
  role: string;
  is_active: boolean;
  plant_id: string | null;
  password_hash: string | null;
  password_salt: string | null;
  profile_enc: Buffer;
  deleted: boolean;
  client_updated_at: Date;
  version: number;
  created_at: Date;
}

export interface UserProfile {
  firstName?: string | null;
  lastName?: string | null;
  phone?: string | null;
  avatarData?: string | null; // base64
}

const profileAad = (tenantId: string, userId: string) => `user:${tenantId}:${userId}`;

export function encryptProfile(key: Buffer, tenantId: string, userId: string, profile: UserProfile): Buffer {
  return encryptJson(key, profile, profileAad(tenantId, userId));
}

export function decryptProfile(key: Buffer, row: Pick<UserRow, "tenant_id" | "id" | "profile_enc">): UserProfile {
  return decryptJson<UserProfile>(key, row.profile_enc, profileAad(row.tenant_id, row.id));
}

/** User in the shared DTO shape (same keys as AppUserDTO in the backups). */
export function userDto(key: Buffer, row: UserRow, includeSecrets = true) {
  const profile = decryptProfile(key, row);
  return {
    id: row.id,
    email: row.email,
    firstName: profile.firstName ?? null,
    lastName: profile.lastName ?? null,
    phone: profile.phone ?? null,
    avatarData: profile.avatarData ?? null,
    roleRaw: row.role,
    isActive: row.is_active,
    plantID: row.plant_id,
    ...(includeSecrets ? { passwordHash: row.password_hash, passwordSalt: row.password_salt } : {}),
    createdAt: row.created_at.toISOString(),
    updatedAt: row.client_updated_at.toISOString(),
  };
}

export async function findUserByEmail(email: string, client: Pick<Tx, "query"> = db()): Promise<UserRow | undefined> {
  const { rows } = await client.query<UserRow>("SELECT * FROM users WHERE lower(email) = lower($1) AND NOT deleted", [email.trim()]);
  return rows[0];
}
