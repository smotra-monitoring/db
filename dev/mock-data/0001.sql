-- Enable foreign keys for this session
PRAGMA foreign_keys = ON;

--------------------------------------------------------------------------------
-- 1. TENANTS & SECTIONS
--------------------------------------------------------------------------------
INSERT INTO tenants (id, name) VALUES 
('019d18cc-fef1-7a00-bc83-a74c951e2e58', 'PepsiCo'),
('019d18cc-fef1-7a00-bc83-a74c951e2e59', 'Coca-Cola');

INSERT INTO sections (id, tenant_id, name) VALUES 
('019d18bf-d0a6-7052-8c59-8110417675f1', '019d18cc-fef1-7a00-bc83-a74c951e2e58', 'USA-East'),
('019d18bf-d0a6-7052-8c59-8110417675f2',  '019d18cc-fef1-7a00-bc83-a74c951e2e58', 'Mexico-City'),
('019d18bf-d0a6-7052-8c59-8110417675f3',  '019d18cc-fef1-7a00-bc83-a74c951e2e59', 'Atlanta-HQ');

--------------------------------------------------------------------------------
-- 2. TAGS (Scoped)
--------------------------------------------------------------------------------
-- Agent-scoped tags for Pepsi USA
INSERT INTO tags (id, section_id, name, scope) VALUES 
('019d18cc-fef1-7ca7-8d05-4dcc8815a5c6',    '019d18bf-d0a6-7052-8c59-8110417675f1', 'role:mesh-node', 'agent'),
('019d18cc-fef1-7ca7-8d05-4dcc8815a5c7',    '019d18bf-d0a6-7052-8c59-8110417675f1', 'env:production', 'agent'),
('019d18cc-fef1-7ca7-8d05-4dcc8815a5c8',     '019d18bf-d0a6-7052-8c59-8110417675f1', 'infra:k8s',      'agent');

-- Endpoint-scoped tags for Pepsi USA
INSERT INTO tags (id, section_id, name, scope) VALUES 
('019d18cc-fef1-7ca7-8d05-4dcc8815a5c9',     '019d18bf-d0a6-7052-8c59-8110417675f1', 'svc:dns',        'endpoint'),
('019d18cc-fef1-7ca7-8d05-4dcc8815a5ca', '019d18bf-d0a6-7052-8c59-8110417675f1', 'svc:gateway',    'endpoint');

--------------------------------------------------------------------------------
-- 3. AGENTS
--------------------------------------------------------------------------------
-- Note: ids are UUIDv7 strings (mocked for readability)
INSERT INTO agents (id, section_id, name, api_key_hash, base_config) VALUES 
-- Agent 1 api key is api_key
('018d1234-5678-7001-8000-000000000001', '019d18bf-d0a6-7052-8c59-8110417675f1', 'pepsi-node-01', '2e9bc6c94a4cbdfe2a31d2df79103a5eb3702eaf5d7018d47a774e9540a8ec29', '{"monitoring":{"interval_secs":60}}'),
('018d1234-5678-7002-8000-000000000002', '019d18bf-d0a6-7052-8c59-8110417675f1', 'pepsi-node-02', 'hash456', '{"monitoring":{"interval_secs":60}}'),
('018d1234-5678-7003-8000-000000000003', '019d18bf-d0a6-7052-8c59-8110417675f2',  'pepsi-mx-01',   'hash789', '{"monitoring":{"interval_secs":30}}');

--------------------------------------------------------------------------------
-- 4. AGENT TAG ASSIGNMENTS (Creating the Mesh)
--------------------------------------------------------------------------------
-- Assign node 01 and 02 to the mesh in USA
INSERT INTO agent_tags (agent_id, tag_id) VALUES 
('018d1234-5678-7001-8000-000000000001', '019d18cc-fef1-7ca7-8d05-4dcc8815a5c6'),
('018d1234-5678-7001-8000-000000000001', '019d18cc-fef1-7ca7-8d05-4dcc8815a5c7'),
('018d1234-5678-7002-8000-000000000002', '019d18cc-fef1-7ca7-8d05-4dcc8815a5c6');

--------------------------------------------------------------------------------
-- 5. STATIC ENDPOINTS (Agent-Specific)
--------------------------------------------------------------------------------
INSERT INTO endpoints (id, agent_id, address, enabled) VALUES 
('018d1234-5678-7002-8000-000000000001', '018d1234-5678-7001-8000-000000000001', '8.8.8.8', 1),
('018d1234-5678-7002-8000-000000000002', '018d1234-5678-7001-8000-000000000001', '1.1.1.1', 1);

-- Tag the static endpoints
INSERT INTO endpoint_tags (endpoint_id, tag_id) VALUES 
('018d1234-5678-7002-8000-000000000001', '019d18cc-fef1-7ca7-8d05-4dcc8815a5c9'),
('018d1234-5678-7002-8000-000000000002', '019d18cc-fef1-7ca7-8d05-4dcc8815a5c9');

INSERT INTO users (id, tenant_id, oauth_provider, oauth_subject, display_name) VALUES
('019d18bf-d0a6-7052-8c59-8110417675f1', '019d18cc-fef1-7a00-bc83-a74c951e2e58', 'google', 'google-subject-123', 'Alice Smith'),
('019d18bf-d0a6-7052-8c59-8110417675f2', '019d18cc-fef1-7a00-bc83-a74c951e2e58', 'github', 'github-subject-456', 'Bob Johnson'),
('019d18bf-d0a6-7052-8c59-8110417675f3', '019d18cc-fef1-7a00-bc83-a74c951e2e59',  'google', 'google-subject-789', 'Charlie Brown');