import { randomBytes, randomUUID } from "node:crypto";
import { afterAll, beforeAll, describe, expect, it } from "vitest";

// Integration tests: the real Hono app against a real Postgres (TEST_DATABASE_URL).
process.env.DATABASE_URL = process.env.TEST_DATABASE_URL ?? "postgres://trama@127.0.0.1:5544/trama_test";
process.env.MASTER_KEY = randomBytes(32).toString("base64");
process.env.JWT_SECRET = randomBytes(48).toString("base64");
process.env.APP_URL = "https://app.test";
delete process.env.GMAIL_USER;

const { app } = await import("../src/app.js");
const { closeDb, db } = await import("../src/db.js");
const { migrate } = await import("../scripts/migrate.js");
const { decrypt, encrypt, hashPassword, makeSalt } = await import("../src/crypto.js");
const { outbox } = await import("../src/mail.js");

type Json = Record<string, any>;

async function call(method: string, path: string, opts: { token?: string; body?: unknown } = {}) {
  const res = await app.request(`/api${path}`, {
    method,
    headers: { "content-type": "application/json", "x-forwarded-for": `10.0.0.${Math.floor(Math.random() * 250)}`, ...(opts.token ? { authorization: `Bearer ${opts.token}` } : {}) },
    body: opts.body === undefined ? undefined : JSON.stringify(opts.body),
  });
  return { status: res.status, json: (await res.json()) as Json };
}

const tokenFrom = (link: string) => new URL(link).searchParams.get("token")!;
const now = (offsetMs = 0) => new Date(Date.now() + offsetMs).toISOString();

let adminToken = "";

beforeAll(async () => {
  await db().query("DROP SCHEMA public CASCADE; CREATE SCHEMA public;");
  await migrate(false);
  const salt = makeSalt();
  await db().query("INSERT INTO platform_admins (email, name, password_hash, password_salt) VALUES ('owner@trama.test', 'Owner', $1, $2)", [
    hashPassword("owner-pass-123", salt), salt,
  ]);
  const login = await call("POST", "/admin/login", { body: { email: "owner@trama.test", password: "owner-pass-123" } });
  expect(login.status).toBe(200);
  adminToken = login.json.accessToken;
});

afterAll(async () => {
  await closeDb();
});

async function newCompany(plan: string, extra: Json = {}) {
  const email = `admin-${randomUUID().slice(0, 8)}@empresa.test`;
  const created = await call("POST", "/admin/tenants", {
    token: adminToken,
    body: { name: `Textiles ${plan}`, plan, months: 12, admin: { firstName: "Laura", lastName: "Méndez", email }, ...extra },
  });
  expect(created.status).toBe(201);
  const accept = await call("POST", "/auth/accept-invite", { body: { token: tokenFrom(created.json.inviteLink), password: "secreto-123" } });
  expect(accept.status).toBe(200);
  return { tenant: created.json.tenant, email };
}

async function login(email: string, platform = "web", deviceId = randomUUID(), password = "secreto-123") {
  return call("POST", "/auth/login", { body: { email, password, device: { id: deviceId, platform, name: `${platform} test` } } });
}

describe("crypto", () => {
  it("authenticates ciphertexts with their AAD", () => {
    const key = randomBytes(32);
    const blob = encrypt(key, Buffer.from("hola"), "rec:a:plants:1");
    expect(decrypt(key, blob, "rec:a:plants:1").toString()).toBe("hola");
    expect(() => decrypt(key, blob, "rec:b:plants:1")).toThrow();
  });

  it("hashes passwords exactly like the iOS and Android apps", () => {
    // Same vector as android DataTest (computed independently with Python hashlib).
    expect(hashPassword("trama123", "AAECAwQFBgcICQoLDA0ODw==")).toBe("zcwRAuc66SSMfJ2S4LMBXmx9ZZUytXkJe52oTpWoI3A=");
  });
});

describe("admin portal", () => {
  it("rejects unauthenticated access and bad credentials", async () => {
    expect((await call("GET", "/admin/tenants")).status).toBe(401);
    expect((await call("POST", "/admin/login", { body: { email: "owner@trama.test", password: "nope" } })).status).toBe(401);
  });

  it("creates a company with plan limits and emails the admin invite", async () => {
    const before = outbox.length;
    const { tenant, email } = await newCompany("planta");
    expect(tenant.limits).toEqual({ maxUsers: 10, maxDevices: 10, maxPlants: 1 });
    expect(outbox.length).toBe(before + 1);
    expect(outbox.at(-1)!.to).toBe(email);
    const list = await call("GET", "/admin/tenants", { token: adminToken });
    expect(list.json.tenants.some((t: Json) => t.id === tenant.id)).toBe(true);
    const stats = await call("GET", "/admin/stats", { token: adminToken });
    expect(stats.json.mrrUsd).toBeGreaterThanOrEqual(99);
  });

  it("invite links are single use", async () => {
    const created = await call("POST", "/admin/tenants", {
      token: adminToken, body: { name: "Una vez", plan: "web", admin: { firstName: "A", email: `once-${randomUUID().slice(0, 6)}@x.test` } },
    });
    const token = tokenFrom(created.json.inviteLink);
    expect((await call("POST", "/auth/accept-invite", { body: { token, password: "secreto-123" } })).status).toBe(200);
    expect((await call("POST", "/auth/accept-invite", { body: { token, password: "otra-clave-1" } })).status).toBe(410);
  });
});

describe("auth and licences", () => {
  it("logs in, refreshes with rotation and logs out", async () => {
    const { email } = await newCompany("planta");
    const first = await login(email, "ios");
    expect(first.status).toBe(200);
    expect(first.json.licence.writable).toBe(true);
    expect(first.json.user.passwordHash).toBeTruthy(); // devices need it for offline login
    const refreshed = await call("POST", "/auth/refresh", { body: { refreshToken: first.json.refreshToken } });
    expect(refreshed.status).toBe(200);
    expect((await call("POST", "/auth/refresh", { body: { refreshToken: first.json.refreshToken } })).status).toBe(401);
    expect((await call("GET", "/auth/me", { token: refreshed.json.accessToken })).json.tenant.plan).toBe("planta");
    await call("POST", "/auth/logout", { token: refreshed.json.accessToken });
    expect((await call("POST", "/auth/refresh", { body: { refreshToken: refreshed.json.refreshToken } })).status).toBe(401);
  });

  it("blocks the native apps on the Web plan but allows the browser", async () => {
    const { email } = await newCompany("web");
    expect((await login(email, "android")).json.error.code).toBe("plan_web_only");
    expect((await login(email, "web")).status).toBe(200);
  });

  it("enforces the device seats of the licence", async () => {
    const { email } = await newCompany("planta", { maxDevices: 1 });
    expect((await login(email, "ios")).status).toBe(200);
    const second = await login(email, "android");
    expect(second.status).toBe(403);
    expect(second.json.error.code).toBe("device_limit");
    expect((await login(email, "web")).status).toBe(200); // browser sessions don't use seats
  });

  it("does not reveal whether an email exists on password reset", async () => {
    expect((await call("POST", "/auth/forgot", { body: { email: "nadie@nada.test" } })).status).toBe(200);
  });
});

describe("sync", () => {
  it("round-trips encrypted records and never stores plaintext", async () => {
    const { email, tenant } = await newCompany("multiplanta");
    const session = (await login(email, "ios")).json;
    const plantId = randomUUID();
    const pushed = await call("POST", "/sync/push", {
      token: session.accessToken,
      body: { changes: [{ entity: "plants", id: plantId, updatedAt: now(), data: { name: "Planta Secreta Norte", maxCapacity: 1800000 } }] },
    });
    expect(pushed.json.applied).toHaveLength(1);

    const { rows } = await db().query<{ payload: Buffer }>("SELECT payload FROM records WHERE tenant_id = $1 AND id = $2", [tenant.id, plantId]);
    expect(rows[0].payload.toString("latin1")).not.toContain("Secreta");

    const pulled = await call("GET", "/sync/pull?cursor=0", { token: session.accessToken });
    const plant = pulled.json.changes.find((ch: Json) => ch.id === plantId);
    expect(plant.data.name).toBe("Planta Secreta Norte");
    expect(pulled.json.changes.some((ch: Json) => ch.entity === "users")).toBe(true);

    const again = await call("GET", `/sync/pull?cursor=${pulled.json.cursor}`, { token: session.accessToken });
    expect(again.json.changes).toHaveLength(0);
  });

  it("resolves conflicts last-writer-wins and returns the server copy", async () => {
    const { email } = await newCompany("planta");
    const session = (await login(email, "web")).json;
    const id = randomUUID();
    await call("POST", "/sync/push", { token: session.accessToken, body: { changes: [{ entity: "clients", id, updatedAt: now(), data: { name: "Nuevo" } }] } });
    const stale = await call("POST", "/sync/push", {
      token: session.accessToken, body: { changes: [{ entity: "clients", id, updatedAt: now(-60_000), data: { name: "Viejo" } }] },
    });
    expect(stale.json.rejected[0].reason).toBe("stale");
    expect(stale.json.rejected[0].server.data.name).toBe("Nuevo");
    const deleted = await call("POST", "/sync/push", { token: session.accessToken, body: { changes: [{ entity: "clients", id, updatedAt: now(1000), deleted: true }] } });
    expect(deleted.json.applied).toHaveLength(1);
    const pulled = await call("GET", "/sync/pull?cursor=0", { token: session.accessToken });
    expect(pulled.json.changes.find((ch: Json) => ch.id === id).deleted).toBe(true);
  });

  it("applies role permissions server-side", async () => {
    const { email } = await newCompany("planta");
    const adminSession = (await login(email, "web")).json;
    const plantManager = { id: randomUUID(), email: `planta-${randomUUID().slice(0, 6)}@x.test` };
    const salt = makeSalt();
    const created = await call("POST", "/sync/push", {
      token: adminSession.accessToken,
      body: { changes: [{ entity: "users", id: plantManager.id, updatedAt: now(), data: {
        email: plantManager.email, firstName: "Jorge", roleRaw: "Gerente de Planta", isActive: true,
        passwordHash: hashPassword("planta-123", salt), passwordSalt: salt,
      } }] },
    });
    expect(created.json.applied).toHaveLength(1);
    const pm = (await login(plantManager.email, "web", randomUUID(), "planta-123")).json;
    const attempt = await call("POST", "/sync/push", {
      token: pm.accessToken,
      body: { changes: [
        { entity: "plants", id: randomUUID(), updatedAt: now(), data: { name: "No" } },
        { entity: "reports", id: randomUUID(), updatedAt: now(), data: { kindRaw: "envio" } },
        { entity: "reports", id: randomUUID(), updatedAt: now(), data: { kindRaw: "planta", produced: 10 } },
      ] },
    });
    expect(attempt.json.rejected.map((r: Json) => r.reason)).toEqual(["forbidden", "forbidden"]);
    expect(attempt.json.applied).toHaveLength(1);
  });

  it("enforces the plant limit of the plan", async () => {
    const { email } = await newCompany("planta"); // 1 plant
    const s = (await login(email, "web")).json;
    const result = await call("POST", "/sync/push", {
      token: s.accessToken,
      body: { changes: [
        { entity: "plants", id: randomUUID(), updatedAt: now(), data: { name: "Uno" } },
        { entity: "plants", id: randomUUID(), updatedAt: now(), data: { name: "Dos" } },
      ] },
    });
    expect(result.json.applied).toHaveLength(1);
    expect(result.json.rejected[0].reason).toBe("limit");
  });

  it("makes data read-only when the licence expires and writable again after renewal", async () => {
    const { email, tenant } = await newCompany("planta");
    const s = (await login(email, "web")).json;
    await call("PATCH", `/admin/tenants/${tenant.id}`, { token: adminToken, body: { expiresAt: now(-86_400_000) } });
    const blocked = await call("POST", "/sync/push", { token: s.accessToken, body: { changes: [{ entity: "clients", id: randomUUID(), updatedAt: now(), data: { name: "X" } }] } });
    expect(blocked.status).toBe(402);
    expect((await call("GET", "/sync/pull?cursor=0", { token: s.accessToken })).status).toBe(200);
    await call("PATCH", `/admin/tenants/${tenant.id}`, { token: adminToken, body: { extendMonths: 12 } });
    const ok = await call("POST", "/sync/push", { token: s.accessToken, body: { changes: [{ entity: "clients", id: randomUUID(), updatedAt: now(), data: { name: "Y" } }] } });
    expect(ok.status).toBe(200);
  });

  it("isolates companies from each other", async () => {
    const a = await newCompany("planta");
    const b = await newCompany("planta");
    const sa = (await login(a.email, "web")).json;
    const sb = (await login(b.email, "web")).json;
    const id = randomUUID();
    await call("POST", "/sync/push", { token: sa.accessToken, body: { changes: [{ entity: "clients", id, updatedAt: now(), data: { name: "Solo A" } }] } });
    const pulledB = await call("GET", "/sync/pull?cursor=0", { token: sb.accessToken });
    expect(pulledB.json.changes.some((ch: Json) => ch.id === id)).toBe(false);
  });
});
