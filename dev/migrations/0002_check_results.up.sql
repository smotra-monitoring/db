--------------------------------------------------------------------------------
-- CHECK_RESULTS — Base table for all monitoring check results
-- Normalized design: common fields here, per-type data in child tables.
--
-- TimescaleDB note (Postgres prod):
-- When migrating to Postgres, this table is a candidate for a TimescaleDB
-- hypertable partitioned on checked_at. The PK strategy (simple id vs.
-- compound id+checked_at) and child-table design will need to be revisited
-- at that point. SQLite dev uses simple id PK.
--------------------------------------------------------------------------------
CREATE TABLE check_results (
    id           TEXT PRIMARY KEY,    -- UUIDv7 from agent; used for deduplication
    agent_id     TEXT NOT NULL,
    endpoint_id  TEXT NOT NULL,       -- FK to endpoints; validated on submission
    check_type   TEXT NOT NULL CHECK(check_type IN ('ping','traceroute','tcpconnect','udpconnect','httpget','plugin')),
    success      INT NOT NULL DEFAULT 0,
    checked_at   DATETIME NOT NULL,  -- Agent clock (when the check was executed)
    received_at  DATETIME NOT NULL DEFAULT (datetime('now')), -- Server receipt time
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE,
    FOREIGN KEY (endpoint_id) REFERENCES endpoints(id) ON DELETE RESTRICT
) WITHOUT ROWID;

-- For time-range queries per agent
CREATE INDEX idx_check_results_agent_checked ON check_results(agent_id, checked_at DESC);
-- For check-type dashboards
CREATE INDEX idx_check_results_type_checked ON check_results(check_type, checked_at DESC);
-- For failure dashboards
CREATE INDEX idx_check_results_success_checked ON check_results(success, checked_at DESC);

--------------------------------------------------------------------------------
-- PING_CHECK_RESULTS
--------------------------------------------------------------------------------
CREATE TABLE check_results_ping (
    check_id             TEXT PRIMARY KEY,
    resolved_ip          TEXT NOT NULL,
    successes            INT NOT NULL DEFAULT 0,
    failures             INT NOT NULL DEFAULT 0,
    avg_response_time_ms REAL,
    success_latencies_json TEXT NOT NULL DEFAULT '[]', -- JSON array of float64
    errors_json          TEXT,                         -- nullable JSON object: {"errors": [...]}
    FOREIGN KEY (check_id) REFERENCES check_results(id) ON DELETE CASCADE
) WITHOUT ROWID;

--------------------------------------------------------------------------------
-- HTTP_GET_CHECK_RESULTS
--------------------------------------------------------------------------------
CREATE TABLE check_results_http_get (
    check_id            TEXT PRIMARY KEY,
    status_code         INT NOT NULL,
    response_time_ms    REAL,
    response_size_bytes INT,
    errors_json         TEXT,                         -- nullable JSON object: {"errors": [...]}
    FOREIGN KEY (check_id) REFERENCES check_results(id) ON DELETE CASCADE
) WITHOUT ROWID;

--------------------------------------------------------------------------------
-- TCP_CONNECT_CHECK_RESULTS
--------------------------------------------------------------------------------
CREATE TABLE check_results_tcp_connect (
    check_id       TEXT PRIMARY KEY,
    resolved_ip    TEXT NOT NULL,
    connected      INT NOT NULL DEFAULT 0,
    connect_time_ms REAL,
    errors_json    TEXT,                         -- nullable JSON object: {"errors": [...]}
    FOREIGN KEY (check_id) REFERENCES check_results(id) ON DELETE CASCADE
) WITHOUT ROWID;

--------------------------------------------------------------------------------
-- UDP_CONNECT_CHECK_RESULTS
--------------------------------------------------------------------------------
CREATE TABLE check_results_udp_connect (
    check_id         TEXT PRIMARY KEY,
    resolved_ip      TEXT NOT NULL,
    probe_successful INT NOT NULL DEFAULT 0,
    response_time_ms REAL,
    errors_json      TEXT,                         -- nullable JSON object: {"errors": [...]}
    FOREIGN KEY (check_id) REFERENCES check_results(id) ON DELETE CASCADE
) WITHOUT ROWID;

--------------------------------------------------------------------------------
-- TRACEROUTE_CHECK_RESULTS
-- Hops are stored in a separate traceroute_hops table for hop-level analytics.
--------------------------------------------------------------------------------
CREATE TABLE check_results_traceroute (
    check_id       TEXT PRIMARY KEY,
    target_reached INT NOT NULL DEFAULT 0,
    total_time_ms  REAL,
    errors_json    TEXT, -- nullable JSON object: {"errors": [...]}
    FOREIGN KEY (check_id) REFERENCES check_results(id) ON DELETE CASCADE
) WITHOUT ROWID;

--------------------------------------------------------------------------------
-- TRACEROUTE_HOPS — Separate table enabling per-hop SQL analytics
-- (e.g. latency at a specific hop number across all paths, path comparison)
--------------------------------------------------------------------------------
CREATE TABLE check_results_traceroute_hops (
    id              TEXT PRIMARY KEY,  -- UUIDv7 server-generated
    check_id        TEXT NOT NULL,
    hop             INT NOT NULL,      -- hop number / TTL
    resolved_ip     TEXT,              -- nullable (timed-out hops have no address)
    hostname        TEXT,              -- nullable
    success_latencies_json TEXT NOT NULL DEFAULT '[]',
    FOREIGN KEY (check_id) REFERENCES check_results(id) ON DELETE CASCADE
) WITHOUT ROWID;

-- Enables: SELECT * FROM check_results_traceroute_hops WHERE check_id = ? ORDER BY hop
CREATE INDEX idx_traceroute_hops_check ON check_results_traceroute_hops(check_id, hop);

-- Enables: SELECT avg(response_time_ms) FROM check_results_traceroute_hops WHERE hop = 5
CREATE INDEX idx_traceroute_hops_hop ON check_results_traceroute_hops(hop);

--------------------------------------------------------------------------------
-- PLUGIN_CHECK_RESULTS
--------------------------------------------------------------------------------
CREATE TABLE check_results_plugin (
    check_id        TEXT PRIMARY KEY,
    plugin_name     TEXT NOT NULL,
    plugin_version  TEXT NOT NULL,
    success         INT NOT NULL DEFAULT 0,
    response_time_ms REAL,
    errors_json     TEXT,                         -- nullable JSON object: {"errors": [...]}
    data_json       TEXT NOT NULL DEFAULT '{}', -- JSON map[string]string
    FOREIGN KEY (check_id) REFERENCES check_results(id) ON DELETE CASCADE
) WITHOUT ROWID;

--------------------------------------------------------------------------------
-- Additional index on endpoints for efficient address lookup when resolving
-- endpoint_id from an agent_id + target_address pair during result submission.
--------------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_endpoints_agent_address ON endpoints(agent_id, address);
