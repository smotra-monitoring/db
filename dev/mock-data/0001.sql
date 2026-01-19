-- Enable foreign keys for this session
PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- 1. TENANTS & SECTIONS
--------------------------------------------------------------------------------
INSERT INTO tenants (id, name) VALUES 
('tnt-pepsi', 'PepsiCo'),
('tnt-coke', 'Coca-Cola');

INSERT INTO sections (id, tenant_id, name) VALUES 
('sec-pepsi-usa', 'tnt-pepsi', 'USA-East'),
('sec-pepsi-mx',  'tnt-pepsi', 'Mexico-City'),
('sec-coke-atl',  'tnt-coke',  'Atlanta-HQ');

--------------------------------------------------------------------------------
-- 2. TAGS (Scoped)
--------------------------------------------------------------------------------
-- Agent-scoped tags for Pepsi USA
INSERT INTO tags (id, section_id, name, scope) VALUES 
('tag-mesh',    'sec-pepsi-usa', 'role:mesh-node', 'agent'),
('tag-prod',    'sec-pepsi-usa', 'env:production', 'agent'),
('tag-k8s',     'sec-pepsi-usa', 'infra:k8s',      'agent');

-- Endpoint-scoped tags for Pepsi USA
INSERT INTO tags (id, section_id, name, scope) VALUES 
('tag-dns',     'sec-pepsi-usa', 'svc:dns',        'endpoint'),
('tag-gateway', 'sec-pepsi-usa', 'svc:gateway',    'endpoint');

--------------------------------------------------------------------------------
-- 3. AGENTS
--------------------------------------------------------------------------------
-- Note: ids are UUIDv7 strings (mocked for readability)
INSERT INTO agents (id, section_id, name, api_key_hash, base_config) VALUES 
('018d1234-5678-7001-8000-000000000001', 'sec-pepsi-usa', 'pepsi-node-01', 'hash123', '{"monitoring":{"interval_secs":60}}'),
('018d1234-5678-7002-8000-000000000002', 'sec-pepsi-usa', 'pepsi-node-02', 'hash456', '{"monitoring":{"interval_secs":60}}'),
('018d1234-5678-7003-8000-000000000003', 'sec-pepsi-mx',  'pepsi-mx-01',   'hash789', '{"monitoring":{"interval_secs":30}}');

--------------------------------------------------------------------------------
-- 4. AGENT TAG ASSIGNMENTS (Creating the Mesh)
--------------------------------------------------------------------------------
-- Assign node 01 and 02 to the mesh in USA
INSERT INTO agent_tags (agent_id, tag_id) VALUES 
('018d1234-5678-7001-8000-000000000001', 'mesh:usa'),
('018d1234-5678-7001-8000-000000000001', 'prod'),
('018d1234-5678-7002-8000-000000000002', 'mesh:usa');

--------------------------------------------------------------------------------
-- 5. STATIC ENDPOINTS (Agent-Specific)
--------------------------------------------------------------------------------
INSERT INTO endpoints (id, agent_id, address, enabled) VALUES 
('end-01', '018d1234-5678-7001-8000-000000000001', '8.8.8.8', 1),
('end-02', '018d1234-5678-7001-8000-000000000001', '1.1.1.1', 1);

-- Tag the static endpoints
INSERT INTO endpoint_tags (endpoint_id, tag_id) VALUES 
('end-01', 'tag-dns'),
('end-02', 'tag-dns');