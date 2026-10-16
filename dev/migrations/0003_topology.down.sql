-- Drop triggers
DROP TRIGGER IF EXISTS trg_topology_members_deleted;
DROP TRIGGER IF EXISTS trg_topology_members_updated;
DROP TRIGGER IF EXISTS trg_topology_members_inserted;
DROP TRIGGER IF EXISTS trg_topologies_updated;
DROP TRIGGER IF EXISTS trg_topologies_inserted;

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS topology_members;
DROP TABLE IF EXISTS topologies;
