PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- 1. TOPOLOGIES
-- A topology defines how monitoring is structured within a section.
-- type:
--   'full-mesh'    — every agent-tagged endpoint monitors every endpoint-tagged endpoint
--   'hub-and-spoke'— agent-tagged endpoints monitor endpoint-tagged endpoints (one-directional)
--   'one-way'      — explicit source→destination, same as hub-and-spoke semantics
--------------------------------------------------------------------------------
CREATE TABLE topologies (
    id          TEXT PRIMARY KEY,
    section_id  TEXT NOT NULL,
    name        TEXT NOT NULL,
    type        TEXT NOT NULL CHECK(type IN ('full-mesh', 'hub-and-spoke', 'one-way')),
    enabled     INT NOT NULL DEFAULT 1,
    updated_at  DATETIME NOT NULL DEFAULT (datetime('now')),
    created_at  DATETIME NOT NULL DEFAULT (datetime('now')),
    UNIQUE(section_id, name),
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE INDEX idx_topologies_section ON topologies(section_id);

--------------------------------------------------------------------------------
-- 2. TOPOLOGY_MEMBERS
-- Maps tags to topologies with a role:
--   'agent'    — tags on this side identify the agents (sources / monitors)
--   'endpoint' — tags on this side identify the endpoints (targets / monitored)
--
-- PRIMARY KEY includes role so the same tag can appear as both 'agent' and
-- 'endpoint' within one topology (enabling full-mesh with a single shared tag).
--------------------------------------------------------------------------------
CREATE TABLE topology_members (
    topology_id  TEXT NOT NULL,
    tag_id       TEXT NOT NULL,
    role         TEXT NOT NULL CHECK(role IN ('agent', 'endpoint')),
    PRIMARY KEY (topology_id, tag_id, role),
    FOREIGN KEY (topology_id) REFERENCES topologies(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id) REFERENCES tags(id) ON DELETE CASCADE
) WITHOUT ROWID;

CREATE INDEX idx_topology_members_tag ON topology_members(tag_id, role);

--------------------------------------------------------------------------------
-- TRIGGERS: TOPOLOGY CONFIG VERSION RIPPLES
--------------------------------------------------------------------------------

-- Trigger 7: Topology Insert/Update
-- Bumps config_version for all agents in the affected section so they re-fetch
-- their configuration when a topology is created or its properties change.
CREATE TRIGGER trg_topologies_inserted
AFTER INSERT ON topologies
FOR EACH ROW
BEGIN
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at     = datetime('now')
    WHERE section_id = NEW.section_id;
END;

CREATE TRIGGER trg_topologies_updated
AFTER UPDATE OF name, type, enabled ON topologies
FOR EACH ROW
BEGIN
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at     = datetime('now')
    WHERE section_id = NEW.section_id;
END;

-- Trigger 8: Topology Member Insert/Update/Delete
-- Bumps config_version for all agents in the topology's section so they
-- re-fetch when monitoring assignments change.
CREATE TRIGGER trg_topology_members_inserted
AFTER INSERT ON topology_members
FOR EACH ROW
BEGIN
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at     = datetime('now')
    WHERE section_id = (SELECT section_id FROM topologies WHERE id = NEW.topology_id);
END;

CREATE TRIGGER trg_topology_members_updated
AFTER UPDATE OF role ON topology_members
FOR EACH ROW
BEGIN
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at     = datetime('now')
    WHERE section_id = (SELECT section_id FROM topologies WHERE id = NEW.topology_id);
END;

CREATE TRIGGER trg_topology_members_deleted
AFTER DELETE ON topology_members
FOR EACH ROW
BEGIN
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at     = datetime('now')
    WHERE section_id = (SELECT section_id FROM topologies WHERE id = OLD.topology_id);
END;
