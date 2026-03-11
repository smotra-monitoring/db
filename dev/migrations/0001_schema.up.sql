PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- 1. TENANTS
--------------------------------------------------------------------------------
CREATE TABLE tenants (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    created_at   TEXT NOT NULL DEFAULT (datetime('now'))
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- 2. USERS
--------------------------------------------------------------------------------
CREATE TABLE users (
    id              TEXT PRIMARY KEY,
    tenant_id       TEXT NOT NULL,
    oauth_provider  TEXT NOT NULL,         -- e.g., 'github', 'google', 'microsoft'
    oauth_subject   TEXT NOT NULL,         -- Unique ID from OAuth provider (sub claim)
    display_name    TEXT NOT NULL,         -- User's display name
    last_login_at   TEXT,                  -- Last successful login
    created_at      TEXT NOT NULL DEFAULT (datetime('now')),
    updated_at      TEXT NOT NULL DEFAULT (datetime('now')),
    UNIQUE(oauth_provider, oauth_subject),
    FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

-- Index for OAuth lookups
CREATE INDEX idx_users_oauth ON users(oauth_provider, oauth_subject);

--------------------------------------------------------------------------------
-- 3. SECTIONS
--------------------------------------------------------------------------------
CREATE TABLE sections (
    id           TEXT PRIMARY KEY,
    tenant_id    TEXT NOT NULL,
    name         TEXT NOT NULL,
    UNIQUE(tenant_id, name),
    FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- 4. TAGS
--------------------------------------------------------------------------------
CREATE TABLE tags (
    id           TEXT PRIMARY KEY,
    section_id   TEXT NOT NULL,
    name         TEXT NOT NULL,
    scope        TEXT NOT NULL CHECK(scope IN ('agent', 'endpoint', 'global')) DEFAULT 'global',
    UNIQUE(section_id, name),
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- 5. AGENT_CLAIMS (Temporary holding table for unclaimed agents)
--------------------------------------------------------------------------------
CREATE TABLE agent_claims (
    id                      TEXT PRIMARY KEY,      -- Agent's self-generated UUIDv7
    claim_token_hash        TEXT NOT NULL,         -- SHA-256 hash of claim token
    hostname                TEXT NOT NULL,         -- Agent's system hostname (used as initial name)
    agent_version           TEXT NOT NULL,         -- Agent software version
    claim_token_expires_at  DATETIME NOT NULL,         -- When claim token expires
    last_seen_at            TEXT NOT NULL DEFAULT (datetime('now')),
    created_at              TEXT NOT NULL DEFAULT (datetime('now')),
    
    -- Claim status
    claimed_at              TEXT,                  -- When user claimed it
    claimed_by_user_id      TEXT,                  -- Who claimed it
    api_key_plaintext       TEXT,                  -- Temporary storage for API key (cleared after delivery)
    api_key_delivered       INT NOT NULL DEFAULT 0, -- Boolean: has agent received API key?
    FOREIGN KEY (claimed_by_user_id) REFERENCES users(id) ON DELETE SET NULL
) WITHOUT ROWID;

-- Index for cleanup of expired claims
CREATE INDEX idx_agent_claims_expires ON agent_claims(claim_token_expires_at);

-- Index for checking delivery status
CREATE INDEX idx_agent_claims_delivery ON agent_claims(claimed_at, api_key_delivered);

--------------------------------------------------------------------------------
-- 6. AGENTS (Production table - only claimed agents)
--------------------------------------------------------------------------------
CREATE TABLE agents (
    id             TEXT PRIMARY KEY,
    section_id     TEXT NOT NULL,
    name           TEXT NOT NULL,
    api_key_hash   TEXT NOT NULL,
    base_config    TEXT NOT NULL DEFAULT '{}', -- JSON Blob
    version        INT NOT NULL DEFAULT 1,
    
    -- Agent metadata
    agent_version  TEXT,                  -- Agent software version
    
    -- Lifecycle tracking
    last_seen_at   TEXT,                  -- Last heartbeat/config fetch
    updated_at     TEXT NOT NULL DEFAULT (datetime('now')),
    created_at     TEXT NOT NULL DEFAULT (datetime('now')),  -- When claimed
    
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- 7. AGENT_TAGS (Junction)
--------------------------------------------------------------------------------
CREATE TABLE agent_tags (
    agent_id    TEXT NOT NULL,
    tag_id      TEXT NOT NULL,
    PRIMARY KEY (agent_id, tag_id),
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- 8. ENDPOINTS
--------------------------------------------------------------------------------
CREATE TABLE endpoints (
    id          TEXT PRIMARY KEY,
    agent_id    TEXT NOT NULL,
    address     TEXT NOT NULL,
    port        INT,
    enabled     INT NOT NULL DEFAULT 1,
    updated_at  TEXT NOT NULL DEFAULT (datetime('now')),
    created_at  TEXT NOT NULL DEFAULT (datetime('now')),
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- 9. ENDPOINT_TAGS (Junction)
--------------------------------------------------------------------------------
CREATE TABLE endpoint_tags (
    endpoint_id TEXT NOT NULL,
    tag_id      TEXT NOT NULL,
    PRIMARY KEY (endpoint_id, tag_id),
    FOREIGN KEY (endpoint_id) REFERENCES endpoints(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- TRIGGERS: AUTOMATIC VERSIONING & UPDATED_AT RIPPLES
--------------------------------------------------------------------------------

-- Trigger 1: Direct Agent Update
-- Bumps version when core agent data changes.
CREATE TRIGGER trg_agents_updated
AFTER UPDATE OF name, section_id, base_config, api_key_hash, agent_version ON agents
FOR EACH ROW
BEGIN
    UPDATE agents 
    SET version = OLD.version + 1,
        updated_at = datetime('now')
    WHERE id = OLD.id;
END;

-- Trigger 2: Direct Endpoint Update
-- Updates endpoint timestamp and bumps parent agent version.
CREATE TRIGGER trg_endpoints_updated
AFTER UPDATE OF address, enabled ON endpoints
FOR EACH ROW
BEGIN
    UPDATE endpoints 
    SET updated_at = datetime('now')
    WHERE id = OLD.id;

    UPDATE agents 
    SET version = version + 1,
        updated_at = datetime('now')
    WHERE id = OLD.agent_id;
END;

-- Trigger 3: New Endpoint Insert
-- Bumps parent agent version when a new target is added.
CREATE TRIGGER trg_endpoints_inserted
AFTER INSERT ON endpoints
FOR EACH ROW
BEGIN
    UPDATE agents 
    SET version = version + 1,
        updated_at = datetime('now')
    WHERE id = NEW.agent_id;
END;

-- Trigger 4: Tag Name Change (The Big Ripple)
-- Updates all affected endpoints and bumps versions for all affected agents.
CREATE TRIGGER trg_tag_name_updated
AFTER UPDATE OF name ON tags
FOR EACH ROW
BEGIN
    -- Ripple to Agents (Agent/Global scope)
    UPDATE agents 
    SET version = version + 1,
        updated_at = datetime('now')
    WHERE id IN (SELECT agent_id FROM agent_tags WHERE tag_id = OLD.id)
    AND (OLD.scope = 'agent' OR OLD.scope = 'global');

    -- Ripple to Endpoints (Endpoint/Global scope)
    UPDATE endpoints 
    SET updated_at = datetime('now')
    WHERE id IN (SELECT endpoint_id FROM endpoint_tags WHERE tag_id = OLD.id)
    AND (OLD.scope = 'endpoint' OR OLD.scope = 'global');

    -- Ripple to parent Agents of those Endpoints
    UPDATE agents 
    SET version = version + 1,
        updated_at = datetime('now')
    WHERE id IN (
        SELECT agent_id FROM endpoints 
        WHERE id IN (SELECT endpoint_id FROM endpoint_tags WHERE tag_id = OLD.id)
    ) AND (OLD.scope = 'endpoint' OR OLD.scope = 'global');
END;

-- Trigger 5: Agent Tag Linkage Change
CREATE TRIGGER trg_agent_tags_changed
AFTER INSERT ON agent_tags
FOR EACH ROW
WHEN (SELECT scope FROM tags WHERE id = NEW.tag_id) IN ('agent', 'global')
BEGIN
    UPDATE agents 
    SET version = version + 1,
        updated_at = datetime('now')
    WHERE id = NEW.agent_id;
END;

-- Trigger 6: Endpoint Tag Linkage Change
CREATE TRIGGER trg_endpoint_tags_changed
AFTER INSERT ON endpoint_tags
FOR EACH ROW
WHEN (SELECT scope FROM tags WHERE id = NEW.tag_id) IN ('endpoint', 'global')
BEGIN
    UPDATE endpoints SET updated_at = datetime('now') WHERE id = NEW.endpoint_id;
    UPDATE agents SET version = version + 1, updated_at = datetime('now')
    WHERE id = (SELECT agent_id FROM endpoints WHERE id = NEW.endpoint_id);
END;

--------------------------------------------------------------------------------
-- AGENT CLAIMS MANAGEMENT
--------------------------------------------------------------------------------

-- Note: Periodic cleanup of expired/delivered claims should be done by a background job
-- Query for cleanup:
-- DELETE FROM agent_claims 
-- WHERE claim_token_expires_at < datetime('now')
--    OR (claimed_at IS NOT NULL AND api_key_delivered = 1);