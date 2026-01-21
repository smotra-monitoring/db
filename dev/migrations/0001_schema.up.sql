-- Enable foreign keys for the current session (Crucial for SQLite!)
PRAGMA foreign_keys = ON;

-- 1. Tenants: Top-level isolation
CREATE TABLE tenants (
    id           TEXT PRIMARY KEY,
    name         TEXT NOT NULL,
    created_at   TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now'))
) STRICT, WITHOUT ROWID;

-- 2. Sections: Divisions within a tenant
CREATE TABLE sections (
    id           TEXT PRIMARY KEY,
    tenant_id    TEXT NOT NULL,
    name         TEXT NOT NULL,
    UNIQUE(tenant_id, name),
    FOREIGN KEY (tenant_id) REFERENCES tenants(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

-- 3. Tags: Scoped definitions for agents or endpoints
CREATE TABLE tags (
    id           TEXT PRIMARY KEY,
    section_id   TEXT NOT NULL,
    name         TEXT NOT NULL,
    scope        TEXT CHECK(scope IN ('agent', 'endpoint', 'global')) DEFAULT 'global',
    UNIQUE(section_id, name),
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

-- 4. Agents: The remote monitoring units
CREATE TABLE agents (
    id             TEXT PRIMARY KEY,
    version        INTEGER NOT NULL DEFAULT 1,
    section_id     TEXT NOT NULL,
    name           TEXT NOT NULL,
    api_key_hash   TEXT NOT NULL,
    base_config    TEXT NOT NULL, -- JSON blob
    last_seen_at   TEXT,
    created_at     TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

-- 5. Agent Tags: Many-to-Many link
CREATE TABLE agent_tags (
    agent_id    TEXT NOT NULL,
    tag_id      TEXT NOT NULL,
    PRIMARY KEY (agent_id, tag_id),
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

-- 6. Endpoints: Specific targets per agent
CREATE TABLE endpoints (
    id          TEXT PRIMARY KEY,
    agent_id    TEXT NOT NULL,
    address     TEXT NOT NULL,
    enabled     INT DEFAULT 1, -- 1 for true, 0 for false
    created_at  TEXT DEFAULT (strftime('%Y-%m-%d %H:%M:%S', 'now')),
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;

-- 7. Endpoint Tags: Many-to-Many link
CREATE TABLE endpoint_tags (
    endpoint_id TEXT NOT NULL,
    tag_id      TEXT NOT NULL,
    PRIMARY KEY (endpoint_id, tag_id),
    FOREIGN KEY (endpoint_id) REFERENCES endpoints(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
) STRICT, WITHOUT ROWID;