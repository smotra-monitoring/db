--------------------------------------------------------------------------------
-- AGENT_VITALS — Time-series host resource metrics reported by agents
--
-- TimescaleDB hypertable partitioned on reported_at.
-- The primary key is (id, reported_at) to satisfy TimescaleDB's requirement
-- that the time dimension be part of every unique/primary constraint.
--
-- Suggested policies (tune to requirements):
--   SELECT add_retention_policy('agent_vitals', INTERVAL '30 days');
--   SELECT add_compression_policy('agent_vitals', INTERVAL '7 days');
--------------------------------------------------------------------------------
CREATE TABLE agent_vitals (
    id                  TEXT NOT NULL,          -- Server-generated UUIDv7
    agent_id            TEXT NOT NULL,
    agent_version       TEXT,
    config_version      INTEGER,
    is_running          BOOLEAN,
    checks_performed    INTEGER,
    checks_successful   INTEGER,
    checks_failed       INTEGER,
    failed_report_count INTEGER,
    server_connected    BOOLEAN,
    cache_capacity      INTEGER,
    cache_len           INTEGER,
    cpu_pct             DOUBLE PRECISION,       -- CPU utilization 0.0–100.0; NULL if not reported
    mem_used_mb         DOUBLE PRECISION,       -- Resident memory in MB; NULL if not reported
    mem_total_mb        DOUBLE PRECISION,       -- Total physical memory in MB; NULL if not reported
    system_uptime_secs  INTEGER,               -- System uptime in seconds; NULL if not reported
    agent_uptime_secs   INTEGER,               -- Agent process uptime in seconds; NULL if not reported
    started_at          TIMESTAMPTZ,
    stopped_at          TIMESTAMPTZ,
    reported_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- Agent clock when snapshot was taken
    received_at         TIMESTAMPTZ NOT NULL DEFAULT NOW(),  -- Server receipt time
    PRIMARY KEY (id, reported_at),              -- Compound PK required by TimescaleDB
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
);

SELECT create_hypertable('agent_vitals', 'reported_at');

-- Primary access pattern: latest N rows for a specific agent
CREATE INDEX idx_agent_vitals_agent_reported ON agent_vitals(agent_id, reported_at DESC);
