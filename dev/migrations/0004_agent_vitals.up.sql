--------------------------------------------------------------------------------
-- AGENT_VITALS — Time-series host resource metrics reported by agents
--
-- Each row is a snapshot of CPU and memory usage from one agent at one point
-- in time.  Snapshots are attached to the heartbeat call; all vitals fields
-- are nullable because the agent may omit them when they are unavailable.
--
-- TimescaleDB note (Postgres prod):
-- This table is a candidate for a TimescaleDB hypertable partitioned on
-- reported_at.  Consider a retention policy (e.g. raw data 30d, 1h rollups 1y).
--------------------------------------------------------------------------------
CREATE TABLE agent_vitals (
    id              TEXT PRIMARY KEY,       -- Server-generated UUIDv7
    agent_id        TEXT NOT NULL,
    agent_version   TEXT,
    config_version  INTEGER,
    is_running       INTEGER,   -- BOOLEAN stored as 0/1
    checks_performed INTEGER,
    checks_successful INTEGER,
    checks_failed    INTEGER,
    failed_report_count INTEGER,
    server_connected INTEGER,   -- BOOLEAN stored as 0/1
    cache_capacity  INTEGER,
    cache_len       INTEGER,
    cpu_pct         REAL,                   -- CPU utilization 0.0–100.0; NULL if not reported
    mem_used_mb     REAL,                   -- Resident memory in MB; NULL if not reported
    mem_total_mb    REAL,                   -- Total physical memory in MB; NULL if not reported
    system_uptime_secs INTEGER,             -- System uptime in seconds; NULL if not reported
    agent_uptime_secs INTEGER,              -- Agent process uptime in seconds; NULL if not reported
    started_at      DATETIME,
    stopped_at      DATETIME,
    reported_at     DATETIME NOT NULL DEFAULT (datetime('now')),      -- Agent clock when snapshot was taken
    received_at     DATETIME NOT NULL DEFAULT (datetime('now')), -- Server receipt time
    FOREIGN KEY (agent_id) REFERENCES agents(id) ON DELETE CASCADE
) WITHOUT ROWID;

-- Primary access pattern: latest N rows for a specific agent
CREATE INDEX idx_agent_vitals_agent_reported ON agent_vitals(agent_id, reported_at DESC);
