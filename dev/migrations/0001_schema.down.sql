-- Drop triggers first (they reference functions and tables)
DROP TRIGGER IF EXISTS trg_endpoint_tags_deleted;
DROP TRIGGER IF EXISTS trg_endpoint_tags_changed;
DROP TRIGGER IF EXISTS trg_agent_tags_changed;
DROP TRIGGER IF EXISTS trg_tag_name_updated;
DROP TRIGGER IF EXISTS trg_endpoints_deleted;
DROP TRIGGER IF EXISTS trg_endpoints_inserted;
DROP TRIGGER IF EXISTS trg_endpoints_updated;
DROP TRIGGER IF EXISTS trg_agents_updated;
DROP TRIGGER IF EXISTS trg_users_updated;

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS endpoint_tags;
DROP TABLE IF EXISTS agent_tags;
DROP TABLE IF EXISTS endpoints;
DROP TABLE IF EXISTS agents;
DROP TABLE IF EXISTS agent_claims;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS workspaces;
DROP TABLE IF EXISTS tenants;
