--------------------------------------------------------------------------------
-- CHECK_RESULTS — Base table for all monitoring check results
--
-- TimescaleDB hypertable partitioned on checked_at.
-- The primary key is (id, checked_at) to satisfy TimescaleDB's requirement
-- that the time dimension be part of every unique/primary constraint.
--
-- NOTE: TimescaleDB does not support foreign key references TO a hypertable.
-- FK constraints from child result tables (check_results_ping etc.) to this
-- table are therefore intentional omissions, not mistakes. Referential
-- integrity at insert time is enforced at the application layer.
--------------------------------------------------------------------------------
CREATE TABLE check_results (
    id           TEXT NOT NULL,            -- UUIDv7 from agent; used for deduplication
    agent_id     TEXT NOT NULL,
    endpoint_id  TEXT NOT NULL,            -- Validated on submission
    check_type   TEXT NOT NULL CHECK(check_type IN ('ping','traceroute','tcpconnect','udpconnect','httpget','plugin')),
    success      BOOLEAN NOT NULL DEFAULT FALSE,
    checked_at   TIMESTAMPTZ NOT NULL,     -- Agent clock (when the check was executed)
    received_at  TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    PRIMARY KEY (id, checked_at),          -- Compound PK required by TimescaleDB
    FOREIGN KEY (agent_id)    REFERENCES agents(id)    ON DELETE CASCADE,
    FOREIGN KEY (endpoint_id) REFERENCES endpoints(id) ON DELETE RESTRICT
);

SELECT create_hypertable('check_results', 'checked_at');

-- For time-range queries per agent
CREATE INDEX idx_check_results_agent_checked  ON check_results(agent_id,    checked_at DESC);
-- For check-type dashboards
CREATE INDEX idx_check_results_type_checked   ON check_results(check_type,  checked_at DESC);
-- For failure dashboards
CREATE INDEX idx_check_results_success_checked ON check_results(success,    checked_at DESC);

--------------------------------------------------------------------------------
-- PING_CHECK_RESULTS
--------------------------------------------------------------------------------
CREATE TABLE check_results_ping (
    check_id                TEXT PRIMARY KEY,
    resolved_ip             TEXT NOT NULL,
    successes               INTEGER NOT NULL DEFAULT 0,
    failures                INTEGER NOT NULL DEFAULT 0,
    success_latencies_json  JSONB NOT NULL DEFAULT '[]',
    errors_json             JSONB          -- NULL when no errors
    -- FK to check_results omitted: TimescaleDB does not support FK refs to hypertables
);

--------------------------------------------------------------------------------
-- HTTP_GET_CHECK_RESULTS
--------------------------------------------------------------------------------
CREATE TABLE check_results_http_get (
    check_id            TEXT PRIMARY KEY,
    status_code         INTEGER NOT NULL,
    response_time_ms    DOUBLE PRECISION,
    response_size_bytes INTEGER,
    errors_json         JSONB
    -- FK to check_results omitted: TimescaleDB does not support FK refs to hypertables
);

--------------------------------------------------------------------------------
-- TCP_CONNECT_CHECK_RESULTS
--------------------------------------------------------------------------------
CREATE TABLE check_results_tcp_connect (
    check_id        TEXT PRIMARY KEY,
    resolved_ip     TEXT NOT NULL,
    connected       BOOLEAN NOT NULL DEFAULT FALSE,
    connect_time_ms DOUBLE PRECISION,
    errors_json     JSONB
    -- FK to check_results omitted: TimescaleDB does not support FK refs to hypertables
);

--------------------------------------------------------------------------------
-- UDP_CONNECT_CHECK_RESULTS
--------------------------------------------------------------------------------
CREATE TABLE check_results_udp_connect (
    check_id         TEXT PRIMARY KEY,
    resolved_ip      TEXT NOT NULL,
    probe_successful BOOLEAN NOT NULL DEFAULT FALSE,
    response_time_ms DOUBLE PRECISION,
    errors_json      JSONB
    -- FK to check_results omitted: TimescaleDB does not support FK refs to hypertables
);

--------------------------------------------------------------------------------
-- TRACEROUTE_CHECK_RESULTS
--------------------------------------------------------------------------------
CREATE TABLE check_results_traceroute (
    check_id       TEXT PRIMARY KEY,
    target_reached BOOLEAN NOT NULL DEFAULT FALSE,
    errors_json    JSONB
    -- FK to check_results omitted: TimescaleDB does not support FK refs to hypertables
);

--------------------------------------------------------------------------------
-- TRACEROUTE_HOPS — Per-hop SQL analytics (avg latency at hop N, path comparison)
--------------------------------------------------------------------------------
CREATE TABLE check_results_traceroute_hops (
    id                      TEXT PRIMARY KEY,   -- UUIDv7 server-generated
    check_id                TEXT NOT NULL,
    hop                     INTEGER NOT NULL,   -- hop number / TTL
    resolved_ip             TEXT,              -- NULL for timed-out hops
    hostname                TEXT,
    success_latencies_json  JSONB NOT NULL DEFAULT '[]'
    -- FK to check_results omitted: TimescaleDB does not support FK refs to hypertables
);

CREATE INDEX idx_traceroute_hops_check ON check_results_traceroute_hops(check_id, hop);
CREATE INDEX idx_traceroute_hops_hop   ON check_results_traceroute_hops(hop);

--------------------------------------------------------------------------------
-- PLUGIN_CHECK_RESULTS
--------------------------------------------------------------------------------
CREATE TABLE check_results_plugin (
    check_id         TEXT PRIMARY KEY,
    plugin_name      TEXT NOT NULL,
    plugin_version   TEXT NOT NULL,
    success          BOOLEAN NOT NULL DEFAULT FALSE,
    response_time_ms DOUBLE PRECISION,
    errors_json      JSONB,
    data_json        JSONB NOT NULL DEFAULT '{}'
    -- FK to check_results omitted: TimescaleDB does not support FK refs to hypertables
);
