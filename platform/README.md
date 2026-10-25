# Trama Platform

Licensing, authentication and **encrypted sync** for the Trama iPad, Android and Web apps,
plus the admin portal API. TypeScript · Hono · Postgres (Neon) · deployed on Vercel.

## Security model

- **Encryption at rest, per company.** Every company gets its own random 256-bit data key
  (DEK). The DEK is stored wrapped (AES-256-GCM) by `MASTER_KEY`, which lives only in the
  Vercel environment. Every synced record and every user profile is AES-256-GCM ciphertext
  under the company DEK, with AAD `tenant/entity/id` so blobs can't be moved between rows
  or companies. The database only sees routing fields (ids, versions, timestamps, emails, roles).
- **In transit:** TLS everywhere (Vercel + Neon `sslmode=require`).
- **Passwords:** PBKDF2-HMAC-SHA256, 120k iterations — the same scheme the apps use, so
  users synced to a device can still sign in with no internet.
- **Tokens:** 15-minute JWT access tokens; opaque refresh tokens (rotated on every use,
  stored as SHA-256) bound to a device. Revoking a device or deactivating a user kills its sessions.
- **Brute force:** Postgres-backed rate limits on logins, invites and resets.
- **Server-side permissions** mirror the app roles (docs/DOMAIN.md), so a modified client
  can't write what its role doesn't allow.

## Licences

| Plan | USD/month | Users | Devices (iPad/Android) | Plants |
|---|---|---|---|---|
| Web | 49 | 5 | 0 (browser only) | 1 |
| Planta | 99 | 10 | 10 | 1 |
| Multiplanta | 249 | 30 | 30 | 5 |
| Empresa | from 590 | custom | custom | custom |

Limits are defaults; the admin portal can override them per company. When a licence expires
or is suspended, data stays readable but sync push returns `402` (read-only).

## API

| Method | Path | |
|---|---|---|
| POST | `/api/auth/login` | `{email, password, device:{id, platform, name}}` → tokens, user, tenant, licence |
| POST | `/api/auth/refresh` | `{refreshToken}` → rotated tokens |
| POST | `/api/auth/logout` · GET `/api/auth/me` | |
| POST | `/api/auth/accept-invite` | `{token, password}` (invites + resets) |
| POST | `/api/auth/forgot` | `{email}` (always 200) |
| GET | `/api/sync/pull?cursor=N&limit=500` | changes with version > cursor |
| POST | `/api/sync/push` | `{changes:[{entity, id, updatedAt, deleted?, data}]}` → applied / rejected |
| POST | `/api/admin/login` | platform owners |
| GET/POST | `/api/admin/tenants` | list / create company + admin invite |
| GET/PATCH | `/api/admin/tenants/:id` | detail / plan, limits, expiry, suspend |
| POST | `/api/admin/tenants/:id/devices/:deviceId/revoke` | free a device seat |
| POST | `/api/admin/tenants/:id/users/:userId/invite` | resend invite / reset |
| GET | `/api/admin/stats` | MRR, companies by plan, expiring soon |

**Sync payloads** use the backup DTO format of the apps (`BackupService.swift` /
Android `Backup.kt`): same field names, ISO-8601 dates, base64 images, UUID ids.
Entities: `plants clients suppliers contacts styles orders assignments reports projects users`.
Conflicts are last-writer-wins on `updatedAt` (clamped to now + 5 min); a stale push is
rejected with the server copy so the client adopts it. Deletes are tombstones.

## Develop

```bash
npm install
cp .env.example .env            # fill DATABASE_URL, MASTER_KEY, JWT_SECRET
npm run migrate
npm run create-admin -- you@example.com "Your Name"   # prints a link to set the password
npm run dev:api                 # http://localhost:8787/api
npm run dev:web                 # http://localhost:5173 (proxies /api to :8787; API_PROXY / WEB_PORT override)
npm test                        # API integration tests (TEST_DATABASE_URL) + web unit tests
npm run typecheck               # API (tsconfig.json) and web (web/tsconfig.json)
npm run build                   # SPA → dist/
```

## Web app and admin portal (`web/`)

One React + Vite + TypeScript SPA (Vite root `web/`, output `dist/`), served by the same
Vercel project: `/api/*` goes to the function, every other path falls back to `index.html`.

| Route | |
|---|---|
| `/login`, `/olvide`, `/activar?token=`, `/restablecer?token=` | company sign-in, forgot password, invite and reset links |
| `/app/...` | the iPad app for the browser (role-based sections, Spanish UI) |
| `/admin/login`, `/admin/activar?token=`, `/admin`, `/admin/empresas/:id` | vendor admin portal |

```
web/src/
  domain/   types (sync DTOs), enums (roles, sections, statuses), rules (DOMAIN.md) + tests
  data/     store (pull/push sync, outbox, IndexedDB cache), db (read model), services (all writes), session
  lib/      api client (token refresh), PBKDF2, formatting (es-MX), prefs, toasts
  ui/       design-system components (KPITile, Pill, CapacityBar, modals, fields) and charts
  app/      screens;  admin/  admin portal (lazy-loaded)
```

- **Session:** device id is a random UUID in `localStorage` (`platform: "web"`); the refresh token
  lives in `localStorage`, the access token only in memory; a 401 triggers one shared refresh.
- **Data:** `/api/sync/pull` cursor loop into memory, cached per company + user in IndexedDB (cleared
  on logout). Writes go through `data/services.ts` (domain rules + role checks), apply optimistically
  and are pushed; `stale` rejections adopt the server copy, other rejections revert and show the
  server message. Pending changes survive brief network drops. Polls every 30 s, on focus and when
  back online. A licence with `writable: false` shows a banner and hides write actions.
- Per-browser preferences (urgency window, calculator constants, theme) live in `localStorage`, like
  the apps keep them per device.

## Deploy (Vercel)

1. New Vercel project → root directory `platform/`.
2. Env vars: `DATABASE_URL` (Neon **pooled**), `MASTER_KEY`, `JWT_SECRET`, `APP_URL`,
   optionally `GMAIL_USER` / `GMAIL_APP_PASSWORD`.
3. Run `npm run migrate` once against Neon, then `npm run create-admin`.

> `MASTER_KEY` can't be recovered: losing it makes all company data unreadable. Store it in
> a password manager. Never commit `.env`.
