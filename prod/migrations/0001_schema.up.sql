--------------------------------------------------------------------------------
-- 1. TENANTS
--------------------------------------------------------------------------------
CREATE TABLE tenants (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL UNIQUE,
    created_at   TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

--------------------------------------------------------------------------------
-- 2. USERS
--------------------------------------------------------------------------------
CREATE TABLE users (
    id              TEXT PRIMARY KEY,
    tenant_id       TEXT NOT NULL,
    oauth_provider  TEXT NOT NULL,         -- e.g., 'github', 'google', 'microsoft'
    oauth_subject   TEXT NOT NULL,         -- Unique ID from OAuth provider (sub claim)
    display_name    TEXT NOT NULL,         -- User's display name
    email           TEXT,                  -- User's email address from OAuth provider
    avatar_url      TEXT,                  -- User's avatar/profile picture URL
    last_login_at   TIMESTAMPTZ,           -- Last successful login
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(oauth_provider, oauth_subject),
    FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE
);

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
);

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
);

--------------------------------------------------------------------------------
-- 5. AGENT_CLAIMS (Temporary holding table for unclaimed agents)
--------------------------------------------------------------------------------
CREATE TABLE agent_claims (
    id                      TEXT PRIMARY KEY,           -- Agent's self-generated UUIDv7
    claim_token_hash        TEXT NOT NULL,              -- SHA-256 hash of claim token
    hostname                TEXT NOT NULL,              -- Agent's system hostname (used as initial name)
    agent_version           TEXT NOT NULL,              -- Agent software version
    ip_addresses_json       JSONB NOT NULL DEFAULT '[]',
    claim_token_expires_at  TIMESTAMPTZ NOT NULL,
    poll_count              INTEGER NOT NULL DEFAULT 0,
    last_seen_at            TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at              TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    -- Claim status
    claimed_at              TIMESTAMPTZ,
    claimed_by_user_id      TEXT,
    api_key_plaintext       TEXT,                       -- Temporary; cleared after delivery
    api_key_delivered       BOOLEAN NOT NULL DEFAULT FALSE,
    FOREIGN KEY (claimed_by_user_id) REFERENCES users(id) ON DELETE SET NULL
);

CREATE INDEX idx_agent_claims_expires      ON agent_claims(claim_token_expires_at);
CREATE INDEX idx_agent_claims_delivery     ON agent_claims(claimed_at, api_key_delivered);
CREATE INDEX idx_agent_claims_poll_count   ON agent_claims(poll_count);

--------------------------------------------------------------------------------
-- 6. AGENTS (Production table - only claimed agents)
--------------------------------------------------------------------------------
CREATE TABLE agents (
    id                  TEXT PRIMARY KEY,
    section_id          TEXT NOT NULL,
    name                TEXT NOT NULL,
    api_key_hash        TEXT NOT NULL,
    base_config         JSONB NOT NULL DEFAULT '{}',
    config_version      INTEGER NOT NULL DEFAULT 1,     -- Incremented on any config change

    -- Agent metadata
    agent_version       TEXT,
    ip_addresses_json   JSONB NOT NULL DEFAULT '[]',

    -- Lifecycle tracking
    last_seen_at              TIMESTAMPTZ,
    last_result_submitted_at  TIMESTAMPTZ,
    updated_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at                TIMESTAMPTZ NOT NULL DEFAULT NOW(),

    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE
);

--------------------------------------------------------------------------------
-- 7. AGENT_TAGS (Junction)
--------------------------------------------------------------------------------
CREATE TABLE agent_tags (
    agent_id    TEXT NOT NULL,
    tag_id      TEXT NOT NULL,
    PRIMARY KEY (agent_id, tag_id),
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id)   REFERENCES tags(id)   ON DELETE CASCADE
);

--------------------------------------------------------------------------------
-- 8. ENDPOINTS
--------------------------------------------------------------------------------
CREATE TABLE endpoints (
    id               TEXT PRIMARY KEY,
    section_id       TEXT NOT NULL,
    address          TEXT NOT NULL,
    port             INTEGER,
    enabled          BOOLEAN NOT NULL DEFAULT TRUE,
    is_agent         BOOLEAN NOT NULL DEFAULT FALSE,   -- TRUE if this endpoint represents an agent
    linked_agent_id  TEXT,                             -- FK to agents.id (nullable)
    updated_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    FOREIGN KEY (section_id)      REFERENCES sections(id) ON DELETE CASCADE,
    FOREIGN KEY (linked_agent_id) REFERENCES agents(id)   ON DELETE SET NULL
);

CREATE INDEX idx_endpoints_section_address ON endpoints(section_id, address);

--------------------------------------------------------------------------------
-- 9. ENDPOINT_TAGS (Junction)
--------------------------------------------------------------------------------
CREATE TABLE endpoint_tags (
    endpoint_id TEXT NOT NULL,
    tag_id      TEXT NOT NULL,
    PRIMARY KEY (endpoint_id, tag_id),
    FOREIGN KEY (endpoint_id) REFERENCES endpoints(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id)      REFERENCES tags(id)      ON DELETE CASCADE
);

--------------------------------------------------------------------------------
-- TRIGGERS: AUTOMATIC VERSIONING & UPDATED_AT RIPPLES
--------------------------------------------------------------------------------

-- Trigger 0: users updated_at
CREATE OR REPLACE FUNCTION fn_users_updated() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_users_updated
BEFORE UPDATE OF tenant_id, oauth_provider, oauth_subject, display_name, email, avatar_url ON users
FOR EACH ROW EXECUTE FUNCTION fn_users_updated();

-- Trigger 1: agents config_version + updated_at on core field change
CREATE OR REPLACE FUNCTION fn_agents_updated() RETURNS TRIGGER AS $$
BEGIN
    NEW.config_version = OLD.config_version + 1;
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_agents_updated
BEFORE UPDATE OF name, section_id, base_config, api_key_hash, agent_version ON agents
FOR EACH ROW EXECUTE FUNCTION fn_agents_updated();

-- Trigger 2: endpoint update → set updated_at + ripple config_version to section agents
CREATE OR REPLACE FUNCTION fn_endpoints_updated() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at = NOW()
    WHERE section_id = OLD.section_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_endpoints_updated
BEFORE UPDATE OF address, enabled ON endpoints
FOR EACH ROW EXECUTE FUNCTION fn_endpoints_updated();

-- Trigger 3: new endpoint → ripple config_version to section agents
CREATE OR REPLACE FUNCTION fn_endpoints_inserted() RETURNS TRIGGER AS $$
BEGIN
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at = NOW()
    WHERE section_id = NEW.section_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_endpoints_inserted
AFTER INSERT ON endpoints
FOR EACH ROW EXECUTE FUNCTION fn_endpoints_inserted();

-- Trigger 3b: endpoint delete → ripple config_version to section agents
CREATE OR REPLACE FUNCTION fn_endpoints_deleted() RETURNS TRIGGER AS $$
BEGIN
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at = NOW()
    WHERE section_id = OLD.section_id;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_endpoints_deleted
AFTER DELETE ON endpoints
FOR EACH ROW EXECUTE FUNCTION fn_endpoints_deleted();

-- Trigger 4: tag name change → ripple to affected agents and endpoints
CREATE OR REPLACE FUNCTION fn_tag_name_updated() RETURNS TRIGGER AS $$
BEGIN
    IF OLD.scope IN ('agent', 'global') THEN
        UPDATE agents
        SET config_version = config_version + 1,
            updated_at = NOW()
        WHERE id IN (SELECT agent_id FROM agent_tags WHERE tag_id = OLD.id);
    END IF;

    IF OLD.scope IN ('endpoint', 'global') THEN
        UPDATE endpoints
        SET updated_at = NOW()
        WHERE id IN (SELECT endpoint_id FROM endpoint_tags WHERE tag_id = OLD.id);

        UPDATE agents
        SET config_version = config_version + 1,
            updated_at = NOW()
        WHERE section_id IN (
            SELECT section_id FROM endpoints
            WHERE id IN (SELECT endpoint_id FROM endpoint_tags WHERE tag_id = OLD.id)
        );
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_tag_name_updated
AFTER UPDATE OF name ON tags
FOR EACH ROW EXECUTE FUNCTION fn_tag_name_updated();

-- Trigger 5: agent tag insert → ripple to agent if tag is agent/global scope
CREATE OR REPLACE FUNCTION fn_agent_tags_changed() RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT scope FROM tags WHERE id = NEW.tag_id) IN ('agent', 'global') THEN
        UPDATE agents
        SET config_version = config_version + 1,
            updated_at = NOW()
        WHERE id = NEW.agent_id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_agent_tags_changed
AFTER INSERT ON agent_tags
FOR EACH ROW EXECUTE FUNCTION fn_agent_tags_changed();

-- Trigger 6: endpoint tag insert → ripple to endpoint + section agents if endpoint/global scope
CREATE OR REPLACE FUNCTION fn_endpoint_tags_changed() RETURNS TRIGGER AS $$
BEGIN
    IF (SELECT scope FROM tags WHERE id = NEW.tag_id) IN ('endpoint', 'global') THEN
        UPDATE endpoints SET updated_at = NOW() WHERE id = NEW.endpoint_id;
        UPDATE agents
        SET config_version = config_version + 1,
            updated_at = NOW()
        WHERE section_id = (SELECT section_id FROM endpoints WHERE id = NEW.endpoint_id);
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_endpoint_tags_changed
AFTER INSERT ON endpoint_tags
FOR EACH ROW EXECUTE FUNCTION fn_endpoint_tags_changed();

-- Trigger 6b: endpoint tag delete → ripple config_version to section agents
CREATE OR REPLACE FUNCTION fn_endpoint_tags_deleted() RETURNS TRIGGER AS $$
BEGIN
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at = NOW()
    WHERE section_id = (SELECT section_id FROM endpoints WHERE id = OLD.endpoint_id);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_endpoint_tags_deleted
AFTER DELETE ON endpoint_tags
FOR EACH ROW EXECUTE FUNCTION fn_endpoint_tags_deleted();
