-- Drop triggers first (they reference functions and tables)
DROP TRIGGER IF EXISTS trg_endpoint_tags_deleted ON endpoint_tags;
DROP TRIGGER IF EXISTS trg_endpoint_tags_changed ON endpoint_tags;
DROP TRIGGER IF EXISTS trg_agent_tags_changed ON agent_tags;
DROP TRIGGER IF EXISTS trg_tag_name_updated ON tags;
DROP TRIGGER IF EXISTS trg_endpoints_deleted ON endpoints;
DROP TRIGGER IF EXISTS trg_endpoints_inserted ON endpoints;
DROP TRIGGER IF EXISTS trg_endpoints_updated ON endpoints;
DROP TRIGGER IF EXISTS trg_agents_updated ON agents;
DROP TRIGGER IF EXISTS trg_users_updated ON users;

-- Drop trigger functions
DROP FUNCTION IF EXISTS fn_endpoint_tags_deleted();
DROP FUNCTION IF EXISTS fn_endpoint_tags_changed();
DROP FUNCTION IF EXISTS fn_agent_tags_changed();
DROP FUNCTION IF EXISTS fn_tag_name_updated();
DROP FUNCTION IF EXISTS fn_endpoints_deleted();
DROP FUNCTION IF EXISTS fn_endpoints_inserted();
DROP FUNCTION IF EXISTS fn_endpoints_updated();
DROP FUNCTION IF EXISTS fn_agents_updated();
DROP FUNCTION IF EXISTS fn_users_updated();

-- Drop tables in reverse dependency order
DROP TABLE IF EXISTS endpoint_tags;
DROP TABLE IF EXISTS agent_tags;
DROP TABLE IF EXISTS endpoints;
DROP TABLE IF EXISTS agents;
DROP TABLE IF EXISTS agent_claims;
DROP TABLE IF EXISTS tags;
DROP TABLE IF EXISTS sections;
DROP TABLE IF EXISTS users;
DROP TABLE IF EXISTS tenants;
