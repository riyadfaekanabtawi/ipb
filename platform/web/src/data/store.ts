// In-memory replica of the company's data, fed by /api/sync/pull and written through an outbox
// that pushes to /api/sync/push. Writes apply optimistically; the server's verdict then either
// confirms them, replaces them (stale → adopt the server copy) or reverts them (forbidden /
// limit / invalid / conflict → restore the previous copy and surface the server's message).
// The replica and the pending outbox are cached in IndexedDB so reloads are instant and short
// offline periods don't lose work.

import { ENTITIES, type Change, type Entity, type EntityMap, type Licence, type ServerChange } from "../domain/types";
import { idbDelete, idbGet, idbSet } from "./idb";
import { t } from "../i18n";

export type Row<E extends Entity = Entity> = EntityMap[E];
type Tables = { [E in Entity]: Map<string, EntityMap[E]> };

export interface OutboxItem extends Change {
  /** The local copy before the first unsent edit (null = it didn't exist). Used to revert. */
  before: Record<string, unknown> | null;
}

export interface Rejection {
  entity: Entity;
  id: string;
  reason: "stale" | "forbidden" | "limit" | "conflict" | "invalid";
  message: string;
  server?: ServerChange;
}

export interface Transport {
  pull(cursor: number): Promise<{ changes: ServerChange[]; cursor: number; hasMore: boolean; licence: Licence }>;
  push(changes: Change[]): Promise<{ applied: { entity: Entity; id: string; version: number }[]; rejected: Rejection[]; licence: Licence }>;
}

export type SyncStatus = "idle" | "syncing" | "offline" | "error";

export interface CommitResult {
  ok: boolean;
  /** Server message when a change was refused (already reverted locally). */
  message?: string;
  /** True when the change is saved locally but not yet confirmed (offline). */
  queued?: boolean;
}

interface Snapshot {
  cursor: number;
  tables: { [E in Entity]?: EntityMap[E][] };
  outbox: OutboxItem[];
  licence: Licence | null;
  savedAt: string;
}

const emptyTables = (): Tables => Object.fromEntries(ENTITIES.map((e) => [e, new Map()])) as unknown as Tables;
const key = (entity: Entity, id: string) => `${entity}:${id}`;
const MAX_BATCH_BYTES = 3_000_000; // the API caps bodies at 4 MB
const MAX_BATCH_ITEMS = 200;

export class DataStore {
  tables: Tables = emptyTables();
  cursor = 0;
  outbox: OutboxItem[] = [];
  licence: Licence | null = null;
  status: SyncStatus = "idle";
  lastSyncAt: Date | null = null;
  loaded = false;
  /** Bumps on every change; React reads it through useSyncExternalStore. */
  version = 0;

  private listeners = new Set<() => void>();
  private flushing: Promise<Rejection[]> | null = null;
  private saveTimer: ReturnType<typeof setTimeout> | null = null;
  /** Keys of the changes whose commit() is awaiting the server; their errors go to the caller. */
  private awaited = new Set<string>();

  constructor(private transport: Transport, private cacheKey: string | null, private onReject: (message: string) => void = () => {}) {}

  subscribe = (fn: () => void) => {
    this.listeners.add(fn);
    return () => this.listeners.delete(fn);
  };

  getVersion = () => this.version;

  private changed() {
    this.version++;
    this.listeners.forEach((fn) => fn());
    this.scheduleSave();
  }

  all<E extends Entity>(entity: E): EntityMap[E][] {
    return [...this.tables[entity].values()];
  }

  get<E extends Entity>(entity: E, id: string | null | undefined): EntityMap[E] | undefined {
    return id ? this.tables[entity].get(id) : undefined;
  }

  get writable() {
    return this.licence?.writable !== false;
  }

  // Cache ------------------------------------------------------------------------------

  async loadCache() {
    if (!this.cacheKey) return;
    const snap = await idbGet<Snapshot>(this.cacheKey);
    if (snap) {
      this.cursor = snap.cursor ?? 0;
      this.outbox = snap.outbox ?? [];
      this.licence = snap.licence ?? null;
      for (const e of ENTITIES) {
        const map = new Map<string, any>();
        for (const row of snap.tables[e] ?? []) map.set(row.id, row);
        (this.tables as any)[e] = map;
      }
      this.loaded = true;
      this.version++;
      this.listeners.forEach((fn) => fn());
    }
  }

  private scheduleSave() {
    if (!this.cacheKey) return;
    if (this.saveTimer) clearTimeout(this.saveTimer);
    this.saveTimer = setTimeout(() => void this.saveNow(), 400);
  }

  async saveNow() {
    if (!this.cacheKey) return;
    const snap: Snapshot = {
      cursor: this.cursor,
      tables: Object.fromEntries(ENTITIES.map((e) => [e, this.all(e)])),
      outbox: this.outbox,
      licence: this.licence,
      savedAt: new Date().toISOString(),
    };
    await idbSet(this.cacheKey, snap);
  }

  async dropCache() {
    if (this.saveTimer) clearTimeout(this.saveTimer);
    this.saveTimer = null;
    if (this.cacheKey) await idbDelete(this.cacheKey);
    this.cacheKey = null;
  }

  // Local mutation helpers --------------------------------------------------------------

  private put(entity: Entity, id: string, data: Record<string, unknown> | null) {
    const table = this.tables[entity] as Map<string, any>;
    if (data) table.set(id, { ...data, id });
    else table.delete(id);
  }

  private pending(entity: Entity, id: string) {
    return this.outbox.some((o) => o.entity === entity && o.id === id);
  }

  // Pull -------------------------------------------------------------------------------

  /** Pulls every change since the cursor (paged). Pending local edits are not overwritten. */
  async pull(): Promise<void> {
    let more = true;
    let guard = 0;
    while (more && guard++ < 1000) {
      const page = await this.transport.pull(this.cursor);
      for (const c of page.changes) {
        if (this.pending(c.entity, c.id)) continue;
        this.put(c.entity, c.id, c.deleted ? null : ((c.data as unknown as Record<string, unknown>) ?? null));
      }
      this.cursor = page.cursor;
      this.licence = page.licence;
      more = page.hasMore && page.changes.length > 0;
      this.loaded = true;
      this.changed();
    }
  }

  /** flush() then pull(), tracking the status shown in the UI. */
  async sync(): Promise<void> {
    this.status = "syncing";
    this.version++;
    this.listeners.forEach((fn) => fn());
    try {
      await this.flush();
      await this.pull();
      this.status = this.outbox.length ? "offline" : "idle";
      this.lastSyncAt = new Date();
    } catch (error: any) {
      this.status = error?.status === 0 ? "offline" : "error";
      if (error?.status === 401) throw error;
    } finally {
      this.changed();
    }
  }

  // Push -------------------------------------------------------------------------------

  /**
   * Applies changes locally, queues them and pushes. Resolves once the server answered
   * (or the network failed, in which case the changes stay queued).
   */
  async commit(changes: Change[]): Promise<CommitResult> {
    if (!changes.length) return { ok: true };
    if (!this.writable) {
      return { ok: false, message: this.licence?.status === "expired" ? t("store.licenceExpired") : t("store.licenceSuspended") };
    }
    for (const c of changes) {
      const existing = this.outbox.find((o) => o.entity === c.entity && o.id === c.id);
      const current = (this.get(c.entity, c.id) as unknown as Record<string, unknown> | undefined) ?? null;
      const item: OutboxItem = { entity: c.entity, id: c.id, updatedAt: c.updatedAt, deleted: !!c.deleted, data: c.deleted ? null : c.data, before: existing ? existing.before : current };
      if (existing) this.outbox[this.outbox.indexOf(existing)] = item;
      else this.outbox.push(item);
      this.put(c.entity, c.id, c.deleted ? null : ((c.data as unknown as Record<string, unknown>) ?? null));
    }
    this.changed();
    const keys = changes.map((c) => key(c.entity, c.id));
    keys.forEach((k) => this.awaited.add(k));
    try {
      const rejected = await this.flush();
      const mine = rejected.filter((r) => r.reason !== "stale" && changes.some((c) => c.entity === r.entity && c.id === r.id));
      if (mine.length) return { ok: false, message: mine[0].message };
      const stale = rejected.find((r) => r.reason === "stale" && changes.some((c) => c.entity === r.entity && c.id === r.id));
      if (stale) return { ok: false, message: t("store.stale") };
      return { ok: true };
    } catch (error: any) {
      if (error?.status === 0) return { ok: true, queued: true };
      return { ok: false, message: error?.message ?? t("svc.saveFailed") };
    } finally {
      keys.forEach((k) => this.awaited.delete(k));
    }
  }

  /** Sends the outbox in batches. Returns every rejection (already resolved locally). */
  flush(): Promise<Rejection[]> {
    if (this.flushing) return this.flushing.catch(() => []).then(() => this.flush());
    if (!this.outbox.length) return Promise.resolve([]);
    this.flushing = (async () => {
      const all: Rejection[] = [];
      try {
        while (this.outbox.length) {
          const batch = this.nextBatch();
          let res: Awaited<ReturnType<Transport["push"]>>;
          try {
            res = await this.transport.push(batch.map(({ before: _b, ...c }) => c));
          } catch (error: any) {
            if (error?.status === 0 || error?.status === 401 || error?.status === 429 || error?.status >= 500) {
              this.status = error?.status === 0 ? "offline" : "error";
              throw error; // keep the outbox; retry later
            }
            // The whole batch was refused (402 read-only licence, 413, 422): revert it.
            if (error?.status === 402) this.licence = this.licence ? { ...this.licence, writable: false, status: this.licence.status === "active" ? "expired" : this.licence.status } : this.licence;
            for (const item of batch) this.revert(item);
            this.removeFromOutbox(batch);
            if (!batch.some((b) => this.awaited.has(key(b.entity, b.id)))) this.onReject(error?.message ?? t("svc.saveFailed"));
            this.changed();
            throw error;
          }
          this.licence = res.licence;
          const rejectedKeys = new Set(res.rejected.map((r) => key(r.entity, r.id)));
          for (const r of res.rejected) {
            const item = batch.find((b) => b.entity === r.entity && b.id === r.id);
            if (r.reason === "stale" && r.server) {
              this.put(r.entity, r.id, r.server.deleted ? null : ((r.server.data as unknown as Record<string, unknown>) ?? null));
            } else if (item) {
              this.revert(item);
              if (!this.awaited.has(key(r.entity, r.id))) this.onReject(r.message);
            }
            all.push(r);
          }
          // Items edited again while this batch was in flight stay queued with their newer data.
          this.outbox = this.outbox.filter((o) => {
            const sent = batch.find((b) => b.entity === o.entity && b.id === o.id);
            if (!sent) return true;
            if (sent !== o) {
              // Re-edited during the flight: keep it, but its baseline is now the server state.
              if (!rejectedKeys.has(key(o.entity, o.id))) o.before = sent.deleted ? null : (sent.data as unknown as Record<string, unknown>);
              return true;
            }
            return false;
          });
          this.changed();
        }
        if (this.status !== "syncing") this.status = "idle";
        return all;
      } finally {
        this.flushing = null;
      }
    })();
    return this.flushing;
  }

  private nextBatch(): OutboxItem[] {
    const batch: OutboxItem[] = [];
    let bytes = 0;
    for (const item of this.outbox) {
      const size = JSON.stringify(item.data ?? {}).length + 200;
      if (batch.length && (bytes + size > MAX_BATCH_BYTES || batch.length >= MAX_BATCH_ITEMS)) break;
      batch.push(item);
      bytes += size;
    }
    return batch;
  }

  private removeFromOutbox(items: OutboxItem[]) {
    this.outbox = this.outbox.filter((o) => !items.includes(o));
  }

  private revert(item: OutboxItem) {
    this.put(item.entity, item.id, item.before);
  }
}

/** Builds a change stamped now, with updatedAt mirrored inside the DTO. */
export function change<E extends Entity>(entity: E, data: EntityMap[E] & { id: string }, now = new Date()): Change<E> {
  const updatedAt = now.toISOString();
  return { entity, id: data.id, updatedAt, deleted: false, data: { ...data, updatedAt, createdAt: (data as { createdAt?: string | null }).createdAt ?? updatedAt } };
}

export function tombstone(entity: Entity, id: string, now = new Date()): Change {
  return { entity, id, updatedAt: now.toISOString(), deleted: true, data: null };
}
