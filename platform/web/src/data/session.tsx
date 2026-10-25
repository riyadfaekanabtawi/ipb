// Company session + data context: bootstraps from the stored refresh token, opens the cached
// replica for (tenant, user), keeps it in sync (every 30 s, on focus and when back online) and
// exposes the read model, the current user and the write services to the screens.

import { createContext, useContext, useEffect, useMemo, useState, useSyncExternalStore, type ReactNode } from "react";
import { asRole, type Role } from "../domain/enums";
import type { Licence, TenantInfo, UserDTO } from "../domain/types";
import * as api from "../lib/api";
import { toast } from "../lib/toast";
import { DB } from "./db";
import { idbClear } from "./idb";
import { Services } from "./services";
import { DataStore, type Transport } from "./store";

const POLL_MS = 30_000;
const LAST_SESSION_KEY = "trama.lastSession";

interface Meta { user: UserDTO; tenant: TenantInfo }

export interface SessionValue {
  store: DataStore;
  services: Services;
  user: UserDTO;
  tenant: TenantInfo;
  role: Role;
  logout: () => Promise<void>;
}

type State =
  | { phase: "loading" }
  | { phase: "anon" }
  | { phase: "ready"; meta: Meta; store: DataStore };

const SessionContext = createContext<SessionValue | null>(null);
const AuthContext = createContext<{ phase: State["phase"]; signIn: (email: string, password: string) => Promise<void> } | null>(null);

const transport: Transport = {
  pull: (cursor) => api.userRequest("GET", `/sync/pull?cursor=${cursor}&limit=500`),
  push: (changes) => api.userRequest("POST", "/sync/push", { changes }),
};

function saveMeta(meta: Meta) {
  const { passwordHash: _h, passwordSalt: _s, avatarData: _a, ...user } = meta.user;
  try {
    localStorage.setItem(LAST_SESSION_KEY, JSON.stringify({ user, tenant: meta.tenant }));
  } catch {
    /* storage unavailable */
  }
}

function loadMeta(): Meta | null {
  try {
    const raw = localStorage.getItem(LAST_SESSION_KEY);
    return raw ? (JSON.parse(raw) as Meta) : null;
  } catch {
    return null;
  }
}

async function openStore(meta: Meta, licence: Licence | null): Promise<DataStore> {
  const store = new DataStore(transport, `replica:${meta.tenant.id}:${meta.user.id}`, (message) => toast(message, "error"));
  await store.loadCache();
  if (licence) store.licence = licence;
  return store;
}

export function SessionProvider({ children }: { children: ReactNode }) {
  const [state, setState] = useState<State>({ phase: api.hasStoredSession() ? "loading" : "anon" });

  // Bootstrap from a stored refresh token (or the cached replica when offline).
  useEffect(() => {
    if (!api.hasStoredSession()) return;
    let cancelled = false;
    (async () => {
      try {
        const s = await api.refreshSession();
        const meta = { user: s.user, tenant: s.tenant };
        saveMeta(meta);
        const store = await openStore(meta, s.licence);
        if (!cancelled) setState({ phase: "ready", meta, store });
      } catch (error) {
        const cached = loadMeta();
        if (error instanceof api.ApiError && error.status === 0 && cached) {
          const store = await openStore(cached, null);
          store.status = "offline";
          if (!cancelled) setState({ phase: "ready", meta: cached, store });
        } else if (!cancelled) setState({ phase: "anon" });
      }
    })();
    return () => {
      cancelled = true;
    };
  }, []);

  // A definitive refresh failure (revoked device, deactivated user) ends the session.
  useEffect(
    () =>
      api.onSessionChange((s) => {
        if (!s) setState((prev) => {
          if (prev.phase === "ready") void prev.store.dropCache();
          return { phase: "anon" };
        });
        else setState((prev) => (prev.phase === "ready" && prev.meta.user.id === s.user.id ? { ...prev, meta: { user: s.user, tenant: s.tenant } } : prev));
      }),
    [],
  );

  // Keep the replica fresh.
  const store = state.phase === "ready" ? state.store : null;
  useEffect(() => {
    if (!store) return;
    const run = () => void store.sync().catch(() => {});
    run();
    const timer = setInterval(run, POLL_MS);
    const onFocus = () => document.visibilityState === "visible" && run();
    window.addEventListener("online", run);
    document.addEventListener("visibilitychange", onFocus);
    return () => {
      clearInterval(timer);
      window.removeEventListener("online", run);
      document.removeEventListener("visibilitychange", onFocus);
    };
  }, [store]);

  const auth = useMemo(
    () => ({
      phase: state.phase,
      signIn: async (email: string, password: string) => {
        const s = await api.login(email, password);
        const meta = { user: s.user, tenant: s.tenant };
        saveMeta(meta);
        setState({ phase: "ready", meta, store: await openStore(meta, s.licence) });
      },
    }),
    [state.phase],
  );

  const version = useSyncExternalStore(store?.subscribe ?? noopSubscribe, store?.getVersion ?? zero);

  const value = useMemo<SessionValue | null>(() => {
    if (state.phase !== "ready") return null;
    const { store, meta } = state;
    // The synced copy of my user wins (role or plant changed by an admin elsewhere).
    const user = store.get("users", meta.user.id) ?? meta.user;
    const tenant = meta.tenant;
    const role = asRole(user.roleRaw);
    const actor = { me: user, role, tenant };
    return {
      store, user, tenant, role,
      services: new Services(store, () => actor),
      logout: async () => {
        await store.dropCache();
        await api.logout();
        try {
          localStorage.removeItem(LAST_SESSION_KEY);
        } catch {
          /* ignore */
        }
        await idbClear();
      },
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [state, version]);

  return (
    <AuthContext.Provider value={auth}>
      <SessionContext.Provider value={value}>{children}</SessionContext.Provider>
    </AuthContext.Provider>
  );
}

const noopSubscribe = () => () => {};
const zero = () => 0;

export function useAuth() {
  const ctx = useContext(AuthContext);
  if (!ctx) throw new Error("useAuth outside SessionProvider");
  return ctx;
}

export function useSession(): SessionValue {
  const ctx = useContext(SessionContext);
  if (!ctx) throw new Error("useSession outside a ready session");
  return ctx;
}

/** Read model, rebuilt only when the store changes. */
export function useDB(): DB {
  const { store } = useSession();
  const version = useSyncExternalStore(store.subscribe, store.getVersion);
  // eslint-disable-next-line react-hooks/exhaustive-deps
  return useMemo(() => new DB(store), [store, version]);
}

/** Reactive view of sync status + licence. */
export function useSyncState() {
  const { store } = useSession();
  useSyncExternalStore(store.subscribe, store.getVersion);
  return { status: store.status, lastSyncAt: store.lastSyncAt, licence: store.licence, pending: store.outbox.length, loaded: store.loaded };
}
