// HTTP client for the Trama API. Company sessions keep the refresh token in localStorage and the
// access token in memory only; a 401 triggers one refresh (shared by concurrent requests) and a
// retry. Admin-portal sessions are separate (no refresh token; access token in sessionStorage).

import type { Licence, TenantInfo, UserDTO } from "../domain/types";
import { getLang, t } from "../i18n";

export class ApiError extends Error {
  constructor(readonly status: number, readonly code: string, message: string) {
    super(message);
  }
}

const REFRESH_KEY = "trama.refreshToken";
const DEVICE_KEY = "trama.deviceId";
const ADMIN_KEY = "trama.adminToken";

function storage(kind: "local" | "session"): Storage | null {
  try {
    return kind === "local" ? window.localStorage : window.sessionStorage;
  } catch {
    return null;
  }
}

/** Persistent random device id for this browser (the API counts web sessions per device). */
export function deviceId(): string {
  const s = storage("local");
  let id = s?.getItem(DEVICE_KEY);
  if (!id) {
    id = crypto.randomUUID();
    s?.setItem(DEVICE_KEY, id);
  }
  return id;
}

function browserName(): string {
  const ua = navigator.userAgent;
  const browser = /Edg\//.test(ua) ? "Edge" : /Chrome\//.test(ua) ? "Chrome" : /Firefox\//.test(ua) ? "Firefox" : /Safari\//.test(ua) ? "Safari" : t("api.browser");
  const os = /Mac OS X/.test(ua) ? "macOS" : /Windows/.test(ua) ? "Windows" : /Android/.test(ua) ? "Android" : /iPhone|iPad/.test(ua) ? "iOS" : /Linux/.test(ua) ? "Linux" : "";
  return `${browser}${os ? ` · ${os}` : ""}`;
}

async function raw(method: string, path: string, body?: unknown, token?: string | null): Promise<Response> {
  return fetch(`/api${path}`, {
    method,
    // The API answers its messages in this language (codes stay the same).
    headers: {
      "accept-language": getLang(),
      ...(body !== undefined ? { "content-type": "application/json" } : {}),
      ...(token ? { authorization: `Bearer ${token}` } : {}),
    },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

async function parse<T>(res: Response): Promise<T> {
  let json: any = null;
  try {
    json = await res.json();
  } catch {
    /* empty or non-JSON body */
  }
  if (!res.ok) {
    throw new ApiError(res.status, json?.error?.code ?? "http_error", json?.error?.message ?? t("api.genericError"));
  }
  return json as T;
}

/** Network failures become an ApiError with status 0 so callers can treat them as "offline". */
async function send(method: string, path: string, body?: unknown, token?: string | null): Promise<Response> {
  try {
    return await raw(method, path, body, token);
  } catch {
    throw new ApiError(0, "offline", t("api.offline"));
  }
}

// Company session ----------------------------------------------------------------------

export interface SessionInfo {
  accessToken: string;
  refreshToken: string;
  expiresIn: number;
  user: UserDTO;
  tenant: TenantInfo;
  licence: Licence;
}

let accessToken: string | null = null;
let refreshing: Promise<SessionInfo> | null = null;
const sessionListeners = new Set<(s: SessionInfo | null) => void>();

export const onSessionChange = (fn: (s: SessionInfo | null) => void) => {
  sessionListeners.add(fn);
  return () => {
    sessionListeners.delete(fn);
  };
};

function adopt(s: SessionInfo): SessionInfo {
  accessToken = s.accessToken;
  storage("local")?.setItem(REFRESH_KEY, s.refreshToken);
  sessionListeners.forEach((fn) => fn(s));
  return s;
}

export const hasStoredSession = () => !!storage("local")?.getItem(REFRESH_KEY);

export function clearSession() {
  accessToken = null;
  storage("local")?.removeItem(REFRESH_KEY);
  sessionListeners.forEach((fn) => fn(null));
}

export async function login(email: string, password: string): Promise<SessionInfo> {
  const res = await send("POST", "/auth/login", { email: email.trim(), password, device: { id: deviceId(), platform: "web", name: browserName() } });
  return adopt(await parse<SessionInfo>(res));
}

/** Rotates the refresh token. Concurrent callers share a single request. */
export function refreshSession(): Promise<SessionInfo> {
  if (refreshing) return refreshing;
  const token = storage("local")?.getItem(REFRESH_KEY);
  if (!token) return Promise.reject(new ApiError(401, "no_session", t("api.signInToContinue")));
  refreshing = (async () => {
    try {
      const res = await send("POST", "/auth/refresh", { refreshToken: token });
      return adopt(await parse<SessionInfo>(res));
    } catch (error) {
      // Only a definitive rejection ends the session; being offline keeps the stored token.
      if (error instanceof ApiError && error.status === 401) clearSession();
      throw error;
    } finally {
      refreshing = null;
    }
  })();
  return refreshing;
}

/** Authenticated company request with transparent refresh on 401. */
export async function userRequest<T>(method: string, path: string, body?: unknown): Promise<T> {
  if (!accessToken) await refreshSession();
  let res = await send(method, path, body, accessToken);
  if (res.status === 401) {
    await refreshSession();
    res = await send(method, path, body, accessToken);
  }
  return parse<T>(res);
}

export async function logout() {
  try {
    if (accessToken) await send("POST", "/auth/logout", {}, accessToken);
  } catch {
    /* offline: the token is dropped locally anyway */
  }
  clearSession();
}

export async function acceptInvite(token: string, password: string) {
  return parse<{ ok: true }>(await send("POST", "/auth/accept-invite", { token, password }));
}

export async function forgotPassword(email: string) {
  return parse<{ ok: true }>(await send("POST", "/auth/forgot", { email: email.trim() }));
}

// Admin portal -------------------------------------------------------------------------

const adminListeners = new Set<() => void>();
export const onAdminChange = (fn: () => void) => {
  adminListeners.add(fn);
  return () => {
    adminListeners.delete(fn);
  };
};

export const adminToken = () => storage("session")?.getItem(ADMIN_KEY) ?? null;

export async function adminLogin(email: string, password: string) {
  const out = await parse<{ accessToken: string; admin: { id: string; name: string } }>(await send("POST", "/admin/login", { email: email.trim(), password }));
  storage("session")?.setItem(ADMIN_KEY, out.accessToken);
  storage("session")?.setItem(`${ADMIN_KEY}.name`, out.admin.name);
  adminListeners.forEach((fn) => fn());
  return out;
}

export const adminName = () => storage("session")?.getItem(`${ADMIN_KEY}.name`) ?? "";

export function adminLogout() {
  storage("session")?.removeItem(ADMIN_KEY);
  storage("session")?.removeItem(`${ADMIN_KEY}.name`);
  adminListeners.forEach((fn) => fn());
}

export async function adminRequest<T>(method: string, path: string, body?: unknown): Promise<T> {
  const res = await send(method, `/admin${path}`, body, adminToken());
  if (res.status === 401) adminLogout();
  return parse<T>(res);
}
