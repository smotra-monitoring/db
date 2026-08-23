--------------------------------------------------------------------------------
-- 1. TOPOLOGIES
-- type:
--   'full-mesh'     — every agent-tagged endpoint monitors every endpoint-tagged endpoint
--   'hub-and-spoke' — agent-tagged endpoints monitor endpoint-tagged endpoints
--   'one-way'       — explicit source→destination, same as hub-and-spoke semantics
--------------------------------------------------------------------------------
CREATE TABLE topologies (
    id          TEXT PRIMARY KEY,
    section_id  TEXT NOT NULL,
    name        TEXT NOT NULL,
    type        TEXT NOT NULL CHECK(type IN ('full-mesh', 'hub-and-spoke', 'one-way')),
    enabled     BOOLEAN NOT NULL DEFAULT TRUE,
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(section_id, name),
    FOREIGN KEY (section_id) REFERENCES sections(id) ON DELETE CASCADE
);

CREATE INDEX idx_topologies_section ON topologies(section_id);

--------------------------------------------------------------------------------
-- 2. TOPOLOGY_MEMBERS
-- Maps tags to topologies with a role:
--   'monitor' — tags identifying agents (sources / monitors)
--   'target'  — tags identifying endpoints (targets / monitored)
--
-- The same tag can appear as both 'monitor' and 'target' (enables full-mesh
-- with a single shared tag).
--------------------------------------------------------------------------------
CREATE TABLE topology_members (
    topology_id  TEXT NOT NULL,
    tag_id       TEXT NOT NULL,
    role         TEXT NOT NULL CHECK(role IN ('monitor', 'target')),
    PRIMARY KEY (topology_id, tag_id, role),
    FOREIGN KEY (topology_id) REFERENCES topologies(id) ON DELETE CASCADE,
    FOREIGN KEY (tag_id)      REFERENCES tags(id)       ON DELETE CASCADE
);

CREATE INDEX idx_topology_members_tag ON topology_members(tag_id, role);

--------------------------------------------------------------------------------
-- TRIGGERS: TOPOLOGY CONFIG VERSION RIPPLES
--------------------------------------------------------------------------------

-- Trigger 7a: topology insert → bump config_version for all agents in section
CREATE OR REPLACE FUNCTION fn_topologies_inserted() RETURNS TRIGGER AS $$
BEGIN
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at = NOW()
    WHERE section_id = NEW.section_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_topologies_inserted
AFTER INSERT ON topologies
FOR EACH ROW EXECUTE FUNCTION fn_topologies_inserted();

-- Trigger 7b: topology update → bump config_version for all agents in section
CREATE OR REPLACE FUNCTION fn_topologies_updated() RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = NOW();
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at = NOW()
    WHERE section_id = NEW.section_id;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_topologies_updated
BEFORE UPDATE OF name, type, enabled ON topologies
FOR EACH ROW EXECUTE FUNCTION fn_topologies_updated();

-- Trigger 8a: topology member insert → bump config_version for section agents
CREATE OR REPLACE FUNCTION fn_topology_members_inserted() RETURNS TRIGGER AS $$
BEGIN
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at = NOW()
    WHERE section_id = (SELECT section_id FROM topologies WHERE id = NEW.topology_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_topology_members_inserted
AFTER INSERT ON topology_members
FOR EACH ROW EXECUTE FUNCTION fn_topology_members_inserted();

-- Trigger 8b: topology member role change → bump config_version for section agents
CREATE OR REPLACE FUNCTION fn_topology_members_updated() RETURNS TRIGGER AS $$
BEGIN
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at = NOW()
    WHERE section_id = (SELECT section_id FROM topologies WHERE id = NEW.topology_id);
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_topology_members_updated
AFTER UPDATE OF role ON topology_members
FOR EACH ROW EXECUTE FUNCTION fn_topology_members_updated();

-- Trigger 8c: topology member delete → bump config_version for section agents
CREATE OR REPLACE FUNCTION fn_topology_members_deleted() RETURNS TRIGGER AS $$
BEGIN
    UPDATE agents
    SET config_version = config_version + 1,
        updated_at = NOW()
    WHERE section_id = (SELECT section_id FROM topologies WHERE id = OLD.topology_id);
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_topology_members_deleted
AFTER DELETE ON topology_members
FOR EACH ROW EXECUTE FUNCTION fn_topology_members_deleted();
