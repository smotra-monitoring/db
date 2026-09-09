-- Drop triggers
DROP TRIGGER IF EXISTS trg_topology_members_deleted ON topology_members;
DROP TRIGGER IF EXISTS trg_topology_members_updated ON topology_members;
DROP TRIGGER IF EXISTS trg_topology_members_inserted ON topology_members;
DROP TRIGGER IF EXISTS trg_topologies_updated ON topologies;
DROP TRIGGER IF EXISTS trg_topologies_inserted ON topologies;

-- Drop trigger functions
DROP FUNCTION IF EXISTS fn_topology_members_deleted();
DROP FUNCTION IF EXISTS fn_topology_members_updated();
DROP FUNCTION IF EXISTS fn_topology_members_inserted();
DROP FUNCTION IF EXISTS fn_topologies_updated();
DROP FUNCTION IF EXISTS fn_topologies_inserted();

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS topology_members;
DROP TABLE IF EXISTS topologies;
