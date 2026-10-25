// Sync store + write services against an in-memory fake of /api/sync (no network, no IndexedDB).

import { describe, expect, it } from "vitest";
import type { Role } from "../domain/enums";
import type { Change, Entity, Licence, ServerChange, UserDTO } from "../domain/types";
import { hashPassword } from "../lib/password";
import { Services } from "./services";
import { DataStore, type Rejection, type Transport } from "./store";

const licence: Licence = { plan: "planta", status: "active", expiresAt: "2099-01-01T00:00:00.000Z", writable: true };

class FakeServer implements Transport {
  version = 0;
  rows = new Map<string, ServerChange>();
  pushes: Change[][] = [];
  offline = false;
  licence = licence;
  /** Optional per-change verdict hook (simulates server-side rules). */
  judge: (c: Change) => Rejection | null = () => null;

  seed(entity: Entity, data: Record<string, unknown> & { id: string }, updatedAt = "2026-01-01T00:00:00.000Z") {
    this.rows.set(`${entity}:${data.id}`, { entity, id: data.id, updatedAt, deleted: false, data: data as never, version: ++this.version });
  }

  async pull(cursor: number) {
    if (this.offline) throw Object.assign(new Error("offline"), { status: 0 });
    const changes = [...this.rows.values()].filter((r) => r.version > cursor).sort((a, b) => a.version - b.version);
    const page = changes.slice(0, 2); // tiny pages to exercise the cursor loop
    return { changes: page, cursor: page.length ? page[page.length - 1].version : cursor, hasMore: changes.length > 2, licence: this.licence };
  }

  async push(changes: Change[]) {
    if (this.offline) throw Object.assign(new Error("offline"), { status: 0 });
    if (!this.licence.writable) throw Object.assign(new Error("Tu licencia venció: los datos son de solo lectura."), { status: 402 });
    this.pushes.push(changes);
    const applied: { entity: Entity; id: string; version: number }[] = [];
    const rejected: Rejection[] = [];
    for (const c of changes) {
      const key = `${c.entity}:${c.id}`;
      const existing = this.rows.get(key);
      if (existing && new Date(existing.updatedAt) > new Date(c.updatedAt)) {
        rejected.push({ entity: c.entity, id: c.id, reason: "stale", message: "Hay una versión más reciente.", server: existing });
        continue;
      }
      const verdict = this.judge(c);
      if (verdict) {
        rejected.push(verdict);
        continue;
      }
      const row: ServerChange = { entity: c.entity, id: c.id, updatedAt: c.updatedAt, deleted: !!c.deleted, data: c.deleted ? null : (c.data ?? null), version: ++this.version };
      this.rows.set(key, row);
      applied.push({ entity: c.entity, id: c.id, version: row.version });
    }
    return { applied, rejected, licence: this.licence };
  }
}

function setup(role: Role = "Administrador", me: Partial<UserDTO> = {}) {
  const server = new FakeServer();
  const rejections: string[] = [];
  const store = new DataStore(server, null, (m) => rejections.push(m));
  const user: UserDTO = { id: crypto.randomUUID(), email: "admin@demo.local", firstName: "Ana", lastName: "López", roleRaw: role, isActive: true, ...me };
  server.seed("users", user as never);
  const services = new Services(store, () => ({ me: store.get("users", user.id) ?? user, role, tenant: { id: "t", name: "Demo", plan: "planta", maxPlants: 2, maxUsers: 3 } }));
  return { server, store, services, user, rejections };
}

const iso = (y: number, m: number, d: number) => new Date(y, m - 1, d, 12).toISOString();

describe("sync store", () => {
  it("pulls every page and advances the cursor", async () => {
    const { server, store } = setup();
    for (let i = 0; i < 5; i++) server.seed("plants", { id: crypto.randomUUID(), name: `P${i}`, maxCapacity: 1000 });
    await store.pull();
    expect(store.all("plants")).toHaveLength(5);
    expect(store.cursor).toBe(server.version);
    server.rows.set(`plants:${store.all("plants")[0].id}`, { ...server.rows.get(`plants:${store.all("plants")[0].id}`)!, deleted: true, data: null, version: ++server.version });
    await store.pull();
    expect(store.all("plants")).toHaveLength(4);
  });

  it("adopts the server copy when a push is stale", async () => {
    const { server, store } = setup();
    const id = crypto.randomUUID();
    server.seed("plants", { id, name: "Servidor", maxCapacity: 5000 }, "2999-01-01T00:00:00.000Z");
    await store.pull();
    const res = await store.commit([{ entity: "plants", id, updatedAt: new Date().toISOString(), data: { id, name: "Local", maxCapacity: 1 } }]);
    expect(res.ok).toBe(false);
    expect(store.get("plants", id)?.name).toBe("Servidor");
    expect(store.outbox).toHaveLength(0);
  });

  it("reverts forbidden or limit rejections and reports the server message", async () => {
    const { server, store } = setup();
    server.judge = (c) => (c.entity === "plants" ? { entity: c.entity, id: c.id, reason: "limit", message: "Tu plan permite 1 planta(s)." } : null);
    const id = crypto.randomUUID();
    const res = await store.commit([{ entity: "plants", id, updatedAt: new Date().toISOString(), data: { id, name: "Nueva", maxCapacity: 10 } }]);
    expect(res).toEqual({ ok: false, message: "Tu plan permite 1 planta(s)." });
    expect(store.get("plants", id)).toBeUndefined();
  });

  it("keeps changes queued while offline and sends them later", async () => {
    const { server, store } = setup();
    server.offline = true;
    const id = crypto.randomUUID();
    const res = await store.commit([{ entity: "clients", id, updatedAt: new Date().toISOString(), data: { id, name: "Textiles del Norte" } }]);
    expect(res).toEqual({ ok: true, queued: true });
    expect(store.get("clients", id)?.name).toBe("Textiles del Norte");
    expect(store.outbox).toHaveLength(1);
    server.offline = false;
    await store.sync();
    expect(store.outbox).toHaveLength(0);
    expect(server.rows.get(`clients:${id}`)?.data).toMatchObject({ name: "Textiles del Norte" });
  });

  it("does not let a pull overwrite a pending local edit", async () => {
    const { server, store } = setup();
    const id = crypto.randomUUID();
    server.seed("clients", { id, name: "Viejo" });
    await store.pull();
    server.offline = true;
    await store.commit([{ entity: "clients", id, updatedAt: new Date().toISOString(), data: { id, name: "Nuevo" } }]);
    server.offline = false;
    server.seed("clients", { id, name: "Viejo" }); // re-delivered by a later pull page
    await store.pull();
    expect(store.get("clients", id)?.name).toBe("Nuevo");
  });

  it("refuses writes in read-only mode", async () => {
    const { server, store } = setup();
    server.licence = { ...licence, status: "expired", writable: false };
    await store.pull();
    const res = await store.commit([{ entity: "clients", id: crypto.randomUUID(), updatedAt: new Date().toISOString(), data: { id: "x", name: "X" } }]);
    expect(res.ok).toBe(false);
    expect(res.message).toMatch(/solo lectura/);
  });
});

describe("write services", () => {
  async function withPlantAndOrder() {
    const ctx = setup();
    await ctx.store.pull();
    const plant = await ctx.services.savePlant(null, "  Planta Norte ", 10_000);
    const order = await ctx.services.saveOrder(null, { code: "C-100", list: "7", garment: "Falda", quantity: 100, unitPrice: 50, clientID: null, styleID: null, internalDate: null, clientDate: iso(2026, 3, 30), notes: "" });
    return { ...ctx, plant, order };
  }

  it("validates catalogs (trimmed, unique, positive capacity, plan limit)", async () => {
    const { services } = await withPlantAndOrder();
    await expect(services.savePlant(null, "planta norte", 5)).rejects.toThrow("Ya existe una planta con ese nombre.");
    await expect(services.savePlant(null, "Sur", 0)).rejects.toThrow("La capacidad máxima mensual debe ser mayor a cero.");
    await expect(services.savePlant(null, " ", 10)).rejects.toThrow("Escribe el nombre de la planta.");
    await services.savePlant(null, "Sur", 10);
    await expect(services.savePlant(null, "Oriente", 10)).rejects.toThrow("Tu plan permite 2 planta(s).");
  });

  it("assigns within remaining quantity and monthly capacity", async () => {
    const { services, store, plant, order } = await withPlantAndOrder();
    await expect(services.assign(order, plant, 120, iso(2026, 3, 3))).rejects.toThrow(/lo que falta por asignar \(100\)/);
    await services.assign(order, plant, 60, iso(2026, 3, 3)); // 3,000 of 10,000
    await services.assign(order, plant, 40, iso(2026, 4, 3));
    expect(store.all("assignments")).toHaveLength(2);
    const other = await services.saveOrder(null, { code: "C-200", list: "", garment: "", quantity: 500, unitPrice: 20, clientID: null, styleID: null, internalDate: null, clientDate: null, notes: "" });
    await expect(services.assign(other, plant, 400, iso(2026, 3, 20))).rejects.toThrow(/capacidad máxima/); // 8,000 > 7,000 left
    await services.assign(other, plant, 350, iso(2026, 3, 20));
  });

  it("allows one cut report per assignment and moves the kanban through it", async () => {
    const { services, store, plant, order } = await withPlantAndOrder();
    const a = await services.assign(order, plant, 50, iso(2026, 3, 3));
    await services.moveCut(a, "en_mesa_de_corte");
    await services.moveCut(store.get("assignments", a.id)!, "listo_para_confeccionar");
    const cuts = store.all("reports").filter((r) => r.kindRaw === "corte");
    expect(cuts).toHaveLength(1);
    expect(store.get("assignments", a.id)?.cuttingStatusRaw).toBe("listo_para_confeccionar");
    await expect(services.saveCutReport(a, "en_espera", 10)).rejects.toThrow(/ya tiene un reporte de corte/);
    await services.deleteReport(cuts[0]);
    expect(store.get("assignments", a.id)?.cuttingStatusRaw).toBe("en_espera");
  });

  it("guards deletes (rule 11) and cascades assignments", async () => {
    const { services, store, plant, order } = await withPlantAndOrder();
    const a = await services.assign(order, plant, 50, iso(2026, 3, 3));
    await expect(services.deletePlant(plant)).rejects.toThrow(/cortes asignados/);
    await services.savePlantReport(a, { operators: 5, absences: 0, produced: 10, ironing: 0, packing: 0, warehouse: 0 });
    await expect(services.unassign(store.get("assignments", a.id)!)).rejects.toThrow(/reportes/);
    await expect(services.deleteOrder(store.get("orders", order.id)!)).rejects.toThrow(/reportes de producción/);
    await services.deleteReport(store.all("reports")[0]);
    await services.deleteOrder(store.get("orders", order.id)!);
    expect(store.all("assignments")).toHaveLength(0);
    expect(store.all("orders")).toHaveLength(0);
  });

  it("syncs client contacts in order, drops blanks and rejects bad emails", async () => {
    const { services, store } = setup();
    await store.pull();
    const drafts = [
      { id: crypto.randomUUID(), name: "Luis", role: "Compras", email: "luis@cliente.mx", phone: "" },
      { id: crypto.randomUUID(), name: " ", role: "", email: "", phone: "" },
      { id: crypto.randomUUID(), name: "Eva", role: "", email: "", phone: "55 1234 5678" },
    ];
    const client = await services.saveClient(null, "Cliente A", "", drafts);
    expect(store.all("contacts").map((c) => [c.name, c.sortIndex, c.clientID])).toEqual([["Luis", 0, client.id], ["Eva", 1, client.id]]);
    await services.saveClient(client, "Cliente A", "", [drafts[2]]);
    expect(store.all("contacts").map((c) => c.name)).toEqual(["Eva"]);
    await expect(services.saveClient(client, "Cliente A", "", [{ ...drafts[0], email: "malo@" }])).rejects.toThrow("El correo «malo@» no es válido.");
  });

  it("creates users with an app-compatible PBKDF2 hash and enforces the user policy", async () => {
    const { services, store, user } = setup();
    await store.pull();
    await expect(services.createUser({ firstName: "Pedro", lastName: "", email: "pedro@x.mx", phone: "", role: "Gerente de Planta", plantID: null, avatarData: null }, "secreto")).rejects.toThrow(/planta asignada/);
    const plant = await services.savePlant(null, "Norte", 100);
    const created = await services.createUser({ firstName: "Pedro", lastName: "", email: " Pedro@X.mx ", phone: "", role: "Gerente de Planta", plantID: plant.id, avatarData: null }, "secreto");
    expect(created.email).toBe("pedro@x.mx");
    expect(created.passwordHash).toBe(await hashPassword("secreto", created.passwordSalt!));
    await expect(services.createUser({ firstName: "Otro", lastName: "", email: "pedro@x.mx", phone: "", role: "Gerente de Cortes", plantID: null, avatarData: null }, "secreto")).rejects.toThrow(/Ya existe un usuario/);
    await expect(services.deleteUser(store.get("users", user.id)!)).rejects.toThrow("No puedes eliminar tu propio usuario.");
    await expect(services.updateUser(store.get("users", user.id)!, { firstName: "Ana", lastName: "", email: user.email!, phone: "", role: "Gerente de Cortes", plantID: null, avatarData: null })).rejects.toThrow("No puedes cambiar tu propio puesto.");
  });

  it("never echoes a stored password hash when editing a user", async () => {
    const { services, store, server } = setup();
    await store.pull();
    const created = await services.createUser({ firstName: "Eva", lastName: "", email: "eva@x.mx", phone: "", role: "Gerente de Envios", plantID: null, avatarData: null }, "secreto");
    await services.updateUser(store.get("users", created.id)!, { firstName: "Eva María", lastName: "", email: "eva@x.mx", phone: "", role: "Gerente de Envios", plantID: null, avatarData: null });
    const last = server.pushes.at(-1)![0];
    expect(last.data).not.toHaveProperty("passwordHash");
    expect(last.data).toMatchObject({ firstName: "Eva María" });
  });

  it("restricts writes by role", async () => {
    const { services, store, server } = setup("Gerente de Planta", { plantID: "p1" });
    server.seed("plants", { id: "p1", name: "Norte", maxCapacity: 1000 });
    server.seed("assignments", { id: "a1", quantity: 10, unitPrice: 1, plantID: "p1", orderID: null });
    server.seed("assignments", { id: "a2", quantity: 10, unitPrice: 1, plantID: "p2", orderID: null });
    await store.pull();
    await expect(services.savePlant(null, "X", 1)).rejects.toThrow(/administrador/);
    await expect(services.saveShipmentReport(store.get("assignments", "a1")!, "1", 5)).rejects.toThrow(/Tu puesto no permite/);
    await expect(services.savePlantReport(store.get("assignments", "a2")!, { operators: 1, absences: 0, produced: 1, ironing: 0, packing: 0, warehouse: 0 })).rejects.toThrow(/tu planta/);
    await services.savePlantReport(store.get("assignments", "a1")!, { operators: 1, absences: 0, produced: 1, ironing: 0, packing: 0, warehouse: 0 });
    // Plant reports never touch the assignment (the server would refuse it for this role).
    expect(server.pushes.at(-1)!.map((c) => c.entity)).toEqual(["reports"]);
  });
});
