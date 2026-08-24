# Dev vs prod differences

The `dev/` and `prod/` migrations describe the same logical schema. This page documents every deliberate difference and the reasoning behind each choice.

## Engine

| | Dev | Prod |
|---|---|---|
| Engine | SQLite 3 | PostgreSQL 15+ with TimescaleDB 2+ |
| File driver | Single file on disk | Connection string / pooler |
| Concurrency | Single-writer | Full MVCC |

## Type mapping

| SQLite (dev) | PostgreSQL (prod) | Notes |
|---|---|---|
| `DATETIME` | `TIMESTAMPTZ` | All timestamps store timezone offset |
| `datetime('now')` | `NOW()` | Default expression syntax |
| `INT` / `INTEGER` used as boolean | `BOOLEAN` | Native boolean; use `TRUE`/`FALSE` literals |
| `INT` / `INTEGER` used as number | `INTEGER` | No change |
| `REAL` | `DOUBLE PRECISION` | |
| `TEXT` storing JSON | `JSONB` | Binary JSON; enables operators like `->`, `@>`, indexing |
| `TEXT` (all other) | `TEXT` | No change |

## Removed SQLite-isms

| SQLite construct | PostgreSQL equivalent | Notes |
|---|---|---|
| `PRAGMA foreign_keys = ON;` | Not needed | FK enforcement is always on in PostgreSQL |
| `WITHOUT ROWID` | Not applicable | PostgreSQL uses heap tables; no rowid concept |
| Table-level `WITHOUT ROWID` PKs | Standard `PRIMARY KEY` | |

## Trigger syntax

SQLite triggers use an embedded `BEGIN ... END` block. PostgreSQL requires a separate trigger function written in PL/pgSQL.

**SQLite pattern:**
```sql
CREATE TRIGGER trg_agents_updated
AFTER UPDATE OF name ON agents
FOR EACH ROW
BEGIN
    UPDATE agents SET config_version = OLD.config_version + 1 WHERE id = OLD.id;
END;
```

**PostgreSQL pattern:**
```sql
CREATE OR REPLACE FUNCTION fn_agents_updated() RETURNS TRIGGER AS $$
BEGIN
    NEW.config_version = OLD.config_version + 1;
    NEW.updated_at = NOW();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_agents_updated
BEFORE UPDATE OF name ON agents
FOR EACH ROW EXECUTE FUNCTION fn_agents_updated();
```

Key differences:
- Same-row mutations use `BEFORE` triggers and modify `NEW` — no need to issue a second `UPDATE` on the same row.
- Cross-table `UPDATE` statements (ripples) can appear inside either `BEFORE` or `AFTER` functions.
- `DELETE` trigger functions return `OLD`; `INSERT`/`UPDATE` functions return `NEW`.

## TimescaleDB hypertables

Two tables are converted to TimescaleDB hypertables in prod:

| Table | Partition column | Reason |
|---|---|---|
| `check_results` | `checked_at` | High insert rate; time-range queries dominate |
| `agent_vitals` | `reported_at` | Time-series metrics; benefits from chunk pruning |

### Primary key change

TimescaleDB requires the time column to be part of every unique and primary key constraint. Both tables therefore use a **compound primary key** in prod:

| Table | Dev PK | Prod PK |
|---|---|---|
| `check_results` | `id` | `(id, checked_at)` |
| `agent_vitals` | `id` | `(id, reported_at)` |

The logical uniqueness guarantee (deduplication by `id`) is unchanged; the compound key simply adds the time column alongside it.

### Foreign keys to hypertables

TimescaleDB **does not support** foreign key constraints that reference a hypertable. As a result, the child result tables (`check_results_ping`, `check_results_http_get`, etc.) do **not** carry a `FOREIGN KEY (check_id) REFERENCES check_results(id)` constraint in prod.

Referential integrity for those relationships is enforced at the application layer on insert. In dev (SQLite) the FK is present and enforced normally.

### Suggested data lifecycle policies (prod only)

```sql
-- Raw vitals kept 30 days; compress chunks older than 7 days
SELECT add_retention_policy('agent_vitals',  INTERVAL '30 days');
SELECT add_compression_policy('agent_vitals', INTERVAL '7 days');

-- Raw check results kept 90 days; compress chunks older than 14 days
SELECT add_retention_policy('check_results',  INTERVAL '90 days');
SELECT add_compression_policy('check_results', INTERVAL '14 days');
```

Tune these intervals to match your storage budget and query lookback requirements.

## Boolean columns

All columns that store boolean values as `INTEGER 0/1` in the SQLite migrations are declared as `BOOLEAN` in the PostgreSQL migrations. The default values are expressed as `TRUE`/`FALSE` rather than `1`/`0`.

| Dev | Prod |
|---|---|
| `enabled INT NOT NULL DEFAULT 1` | `enabled BOOLEAN NOT NULL DEFAULT TRUE` |
| `api_key_delivered INT NOT NULL DEFAULT 0` | `api_key_delivered BOOLEAN NOT NULL DEFAULT FALSE` |
| `is_agent INT NOT NULL DEFAULT 0` | `is_agent BOOLEAN NOT NULL DEFAULT FALSE` |
| `revoked INTEGER NOT NULL DEFAULT 0` | `revoked BOOLEAN NOT NULL DEFAULT FALSE` |

## JSON columns

All columns that store serialised JSON are `TEXT` in SQLite and `JSONB` in PostgreSQL.

`JSONB` advantages in prod:
- Binary storage — faster reads and comparisons
- Operator support: `->`, `->>`, `@>`, `?`, `#>`
- Indexable with GIN indexes (add as needed for query patterns)

Example GIN index on agent base config:
```sql
CREATE INDEX idx_agents_base_config ON agents USING GIN (base_config);
```
