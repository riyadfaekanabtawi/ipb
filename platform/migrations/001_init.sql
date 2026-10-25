-- Trama platform schema.
-- Business data never sits in plaintext: every synced record is AES-256-GCM ciphertext
-- encrypted with its company's data key (DEK), and each DEK is itself wrapped by the
-- platform master key (MASTER_KEY env). Only routing/authorization fields are plaintext.

CREATE EXTENSION IF NOT EXISTS pgcrypto; -- gen_random_uuid()

-- One global, monotonically increasing version for every change: sync cursors use it.
CREATE SEQUENCE sync_version_seq;

CREATE TABLE tenants (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name            text NOT NULL,
    plan            text NOT NULL CHECK (plan IN ('web', 'planta', 'multiplanta', 'empresa')),
    status          text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
    max_users       integer NOT NULL,
    max_devices     integer NOT NULL,         -- physical devices running the iPad/Android app
    max_plants      integer NOT NULL,
    expires_at      timestamptz NOT NULL,
    dek_wrapped     bytea NOT NULL,           -- company data key, wrapped with MASTER_KEY
    key_version     integer NOT NULL DEFAULT 1,
    contact_email   text,
    notes           text,
    created_at      timestamptz NOT NULL DEFAULT now(),
    updated_at      timestamptz NOT NULL DEFAULT now()
);

-- Company users. Email is plaintext (login lookup); profile fields are encrypted.
-- password_hash/salt use the same PBKDF2-SHA256 scheme as the apps, so synced users can
-- sign in offline on their devices.
CREATE TABLE users (
    id              uuid PRIMARY KEY,
    tenant_id       uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    email           text NOT NULL,
    role            text NOT NULL,
    is_active       boolean NOT NULL DEFAULT true,
    plant_id        uuid,
    password_hash   text,
    password_salt   text,
    profile_enc     bytea NOT NULL,           -- {firstName, lastName, phone, avatarData}
    deleted         boolean NOT NULL DEFAULT false,
    client_updated_at timestamptz NOT NULL,
    version         bigint NOT NULL DEFAULT nextval('sync_version_seq'),
    created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE UNIQUE INDEX users_email_unique ON users (lower(email)) WHERE NOT deleted;
CREATE INDEX users_tenant_version ON users (tenant_id, version);

-- Every other synced entity (plants, clients, suppliers, contacts, styles, orders,
-- assignments, reports, projects). payload = encrypted JSON in the shared DTO format
-- (same field names as the iOS/Android backup files). NULL payload + deleted = tombstone.
CREATE TABLE records (
    tenant_id       uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    entity          text NOT NULL,
    id              uuid NOT NULL,
    payload         bytea,
    deleted         boolean NOT NULL DEFAULT false,
    client_updated_at timestamptz NOT NULL,
    version         bigint NOT NULL DEFAULT nextval('sync_version_seq'),
    updated_by      uuid,
    updated_device  uuid,
    PRIMARY KEY (tenant_id, entity, id)
);
CREATE INDEX records_tenant_version ON records (tenant_id, version);

-- Devices and browser sessions. Refresh tokens are stored as SHA-256 hashes only.
CREATE TABLE devices (
    id              uuid PRIMARY KEY,
    tenant_id       uuid NOT NULL REFERENCES tenants(id) ON DELETE CASCADE,
    user_id         uuid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    platform        text NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    name            text,
    refresh_hash    text NOT NULL,
    refresh_expires timestamptz NOT NULL,
    created_at      timestamptz NOT NULL DEFAULT now(),
    last_seen_at    timestamptz NOT NULL DEFAULT now(),
    revoked_at      timestamptz
);
CREATE INDEX devices_tenant ON devices (tenant_id) WHERE revoked_at IS NULL;
CREATE UNIQUE INDEX devices_refresh ON devices (refresh_hash);

-- One-time links: company admin invitations and password resets (hashed tokens).
CREATE TABLE invites (
    token_hash      text PRIMARY KEY,
    kind            text NOT NULL CHECK (kind IN ('invite', 'reset', 'platform_admin')),
    user_id         uuid,
    admin_id        uuid,
    expires_at      timestamptz NOT NULL,
    used_at         timestamptz,
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- Platform owners (the admin portal). Separate from company users on purpose.
CREATE TABLE platform_admins (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    email           text NOT NULL UNIQUE,
    name            text NOT NULL,
    password_hash   text,
    password_salt   text,
    created_at      timestamptz NOT NULL DEFAULT now()
);

-- Brute-force protection for logins (per email and per IP, sliding window).
CREATE TABLE login_attempts (
    key             text NOT NULL,
    at              timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX login_attempts_key_at ON login_attempts (key, at);

-- Who did what in the admin portal and on licences.
CREATE TABLE audit_log (
    id              bigserial PRIMARY KEY,
    at              timestamptz NOT NULL DEFAULT now(),
    actor           text NOT NULL,
    action          text NOT NULL,
    tenant_id       uuid,
    detail          jsonb
);

CREATE TABLE schema_migrations (
    name            text PRIMARY KEY,
    applied_at      timestamptz NOT NULL DEFAULT now()
);
