--------------------------------------------------------------------------------
-- 1. OAUTH2_PENDING_STATES
-- Short-lived records tracking the authorize→callback→token flow.
-- Lifecycle: created at /authorize → auth_code set at /callback → deleted at /token (one-time use).
--------------------------------------------------------------------------------
CREATE TABLE oauth2_pending_states (
    id          TEXT PRIMARY KEY,                               -- UUIDv7
    state       TEXT NOT NULL UNIQUE,                          -- Client-supplied CSRF param from /authorize
    provider    TEXT NOT NULL,                                 -- OAuth2 provider name (e.g. 'github', 'google')
    auth_code   TEXT,                                          -- Authorization code filled in at /callback
    created_at  DATETIME NOT NULL DEFAULT (datetime('now')),
    expires_at  DATETIME NOT NULL                              -- Set to now + 10 minutes at creation
) WITHOUT ROWID;

CREATE INDEX idx_pending_states_state      ON oauth2_pending_states(state);
CREATE INDEX idx_pending_states_auth_code  ON oauth2_pending_states(auth_code);
CREATE INDEX idx_pending_states_expires_at ON oauth2_pending_states(expires_at);

--------------------------------------------------------------------------------
-- 2. SESSIONS
-- Long-lived server-managed sessions backed by an opaque token (SHA-256 stored).
-- sliding_expires_at is a sliding window (now + 7 days), extended on each transparent IDP refresh,
-- capped by expires_at (created_at + 90 days, hard cap).
--------------------------------------------------------------------------------
CREATE TABLE sessions (
    id                          TEXT PRIMARY KEY,                           -- UUIDv7
    user_id                     TEXT NOT NULL,                              -- FK → users.id
    token_hash                  TEXT NOT NULL UNIQUE,                       -- SHA-256 of plaintext opaque token (plaintext never stored)
    created_at                  DATETIME NOT NULL DEFAULT (datetime('now')),
    sliding_expires_at          DATETIME NOT NULL,                          -- Sliding: now + 7 days, capped at expires_at
    expires_at                  DATETIME NOT NULL,                          -- Hard cap: created_at + 90 days, never updated
    last_used_at                DATETIME NOT NULL DEFAULT (datetime('now')),
    revoked                     INTEGER NOT NULL DEFAULT 0,                 -- Boolean: 1 = revoked

    -- Identity provider
    oauth2_provider             TEXT NOT NULL,                              -- e.g. 'github', 'google'

    -- IDP tokens (stored server-side, never returned to client)
    oauth2_access_token         TEXT NOT NULL,
    oauth2_refresh_token        TEXT,                                       -- NULL for providers that don't issue refresh tokens
    oauth2_token_expiry         DATETIME,                                   -- IDP access token expiry (~1hr typically)
    oauth2_id_token             TEXT,                                       -- OIDC id_token; used as id_token_hint on logout
    oauth2_scope                TEXT,
    oauth2_token_type           TEXT NOT NULL DEFAULT 'Bearer',
    oauth2_token_refresh_count  INTEGER NOT NULL DEFAULT 0,                 -- How many times the IDP token has been refreshed
    oauth2_token_refresh_last_at DATETIME,                                  -- Last time IDP token was refreshed

    FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE INDEX idx_sessions_token_hash         ON sessions(token_hash);
CREATE INDEX idx_sessions_user_id            ON sessions(user_id);
CREATE INDEX idx_sessions_sliding_expires_at ON sessions(sliding_expires_at);
CREATE INDEX idx_sessions_expires_at         ON sessions(expires_at);
