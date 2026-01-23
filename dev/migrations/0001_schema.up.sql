PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- 1. TENANTS
--------------------------------------------------------------------------------
CREATE TABLE tenants (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    created_at   TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now'))
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- 2. SECTIONS
--------------------------------------------------------------------------------
CREATE TABLE sections (
    id           TEXT PRIMARY KEY,
    tenant_id    TEXT NOT NULL,
    name         TEXT NOT NULL,
    UNIQUE(tenant_id, name),
    FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- 3. TAGS
--------------------------------------------------------------------------------
CREATE TABLE tags (
    id           TEXT PRIMARY KEY,
    section_id   TEXT NOT NULL,
    name         TEXT NOT NULL,
    scope        TEXT CHECK(scope IN ('agent', 'endpoint', 'global')) DEFAULT 'global',
    UNIQUE(section_id, name),
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- 4. AGENTS
--------------------------------------------------------------------------------
CREATE TABLE agents (
    id             TEXT PRIMARY KEY,
    section_id     TEXT NOT NULL,
    name           TEXT NOT NULL,
    api_key_hash   TEXT NOT NULL,
    base_config    TEXT NOT NULL, -- JSON Blob
    version        INT DEFAULT 1,
    last_seen_at   TEXT,          -- Nullable
    updated_at     TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
    created_at     TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- 5. AGENT_TAGS (Junction)
--------------------------------------------------------------------------------
CREATE TABLE agent_tags (
    agent_id    TEXT NOT NULL,
    tag_id      TEXT NOT NULL,
    PRIMARY KEY (agent_id, tag_id),
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- 6. ENDPOINTS
--------------------------------------------------------------------------------
CREATE TABLE endpoints (
    id          TEXT PRIMARY KEY,
    agent_id    TEXT NOT NULL,
    address     TEXT NOT NULL,
    enabled     INT DEFAULT 1,
    updated_at  TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
    created_at  TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

--------------------------------------------------------------------------------
-- 7. ENDPOINT_TAGS (Junction)
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
AFTER UPDATE OF name, section_id, base_config, api_key_hash ON agents
FOR EACH ROW
BEGIN
    UPDATE agents 
    SET version = OLD.version + 1,
        updated_at = strftime('%Y-%m-%d %H:%M:%S', 'now')
    WHERE id = OLD.id;
END;

-- Trigger 2: Direct Endpoint Update
-- Updates endpoint timestamp and bumps parent agent version.
CREATE TRIGGER trg_endpoints_updated
AFTER UPDATE OF address, enabled ON endpoints
FOR EACH ROW
BEGIN
    UPDATE endpoints 
    SET updated_at = strftime('%Y-%m-%d %H:%M:%S', 'now')
    WHERE id = OLD.id;

    UPDATE agents 
    SET version = version + 1,
        updated_at = strftime('%Y-%m-%d %H:%M:%S', 'now')
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
        updated_at = strftime('%Y-%m-%d %H:%M:%S', 'now')
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
        updated_at = strftime('%Y-%m-%d %H:%M:%S', 'now')
    WHERE id IN (SELECT agent_id FROM agent_tags WHERE tag_id = OLD.id)
    AND (OLD.scope = 'agent' OR OLD.scope = 'global');

    -- Ripple to Endpoints (Endpoint/Global scope)
    UPDATE endpoints 
    SET updated_at = strftime('%Y-%m-%d %H:%M:%S', 'now')
    WHERE id IN (SELECT endpoint_id FROM endpoint_tags WHERE tag_id = OLD.id)
    AND (OLD.scope = 'endpoint' OR OLD.scope = 'global');

    -- Ripple to parent Agents of those Endpoints
    UPDATE agents 
    SET version = version + 1,
        updated_at = strftime('%Y-%m-%d %H:%M:%S', 'now')
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
        updated_at = strftime('%Y-%m-%d %H:%M:%S', 'now')
    WHERE id = NEW.agent_id;
END;

-- Trigger 6: Endpoint Tag Linkage Change
CREATE TRIGGER trg_endpoint_tags_changed
AFTER INSERT ON endpoint_tags
FOR EACH ROW
WHEN (SELECT scope FROM tags WHERE id = NEW.tag_id) IN ('endpoint', 'global')
BEGIN
    UPDATE endpoints SET updated_at = strftime('%Y-%m-%d %H:%M:%S', 'now') WHERE id = NEW.endpoint_id;
    UPDATE agents SET version = version + 1, updated_at = strftime('%Y-%m-%d %H:%M:%S', 'now')
    WHERE id = (SELECT agent_id FROM endpoints WHERE id = NEW.endpoint_id);
END;