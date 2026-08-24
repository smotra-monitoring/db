# smotra/db

Database migrations and schema for the Smotra monitoring platform.

## Repository layout

```
db/
├── dev/
│   ├── migrations/          # SQLite migrations (local development)
│   ├── mock-data/           # Seed data for development
│   └── sqlc/
│       └── sqlc.yaml        # sqlc code-generation config (SQLite engine)
├── prod/
│   └── migrations/          # PostgreSQL + TimescaleDB migrations (production)
└── docs/                    # This documentation
```

## Environments

| | Dev | Prod |
|---|---|---|
| Engine | SQLite 3 | PostgreSQL + TimescaleDB |
| Migration tool | Any SQLite runner | Any Postgres runner (e.g. `migrate`, `goose`, `flyway`) |
| Time-series | — | `check_results` and `agent_vitals` are TimescaleDB hypertables |
| Boolean type | `INTEGER` (0/1) | `BOOLEAN` |
| JSON type | `TEXT` | `JSONB` |
| Timestamps | `DATETIME` | `TIMESTAMPTZ` |

## Migrations

Each file is numbered and self-contained. Apply them in order.

| # | File | Contents |
|---|------|----------|
| 0001 | `0001_schema.up.sql` | Core schema: tenants, users, sections, tags, agents, endpoints, all triggers |
| 0002 | `0002_check_results.up.sql` | Check result tables (base + per-type); TimescaleDB hypertable on `checked_at` |
| 0003 | `0003_topology.up.sql` | Topology and topology_members tables + triggers |
| 0004 | `0004_agent_vitals.up.sql` | Agent vitals time-series; TimescaleDB hypertable on `reported_at` |
| 0005 | `0005_sessions.up.sql` | OAuth2 pending states and session management |

### Running dev migrations (SQLite)

**Option A — sqlite3 CLI**

```sh
sqlite3 smotra.db < dev/migrations/0001_schema.up.sql
sqlite3 smotra.db < dev/migrations/0002_check_results.up.sql
sqlite3 smotra.db < dev/migrations/0003_topology.up.sql
sqlite3 smotra.db < dev/migrations/0004_agent_vitals.up.sql
sqlite3 smotra.db < dev/migrations/0005_sessions.up.sql

# Optional: load mock data
sqlite3 smotra.db < dev/mock-data/0001.sql
```

**Option B — [golang-migrate](https://github.com/golang-migrate/migrate)**

```sh
migrate -path dev/migrations -database "sqlite3://smotra.db" up
```

Roll back all applied migrations:

```sh
migrate -path dev/migrations -database "sqlite3://smotra.db" down
```

### Running prod migrations (PostgreSQL + TimescaleDB)

TimescaleDB must be installed and the extension enabled before applying migration 0002 or 0004.

```sql
-- Once, as superuser
CREATE EXTENSION IF NOT EXISTS timescaledb;
```

**Option A — psql CLI**

```sh
psql $DATABASE_URL -f prod/migrations/0001_schema.up.sql
psql $DATABASE_URL -f prod/migrations/0002_check_results.up.sql
psql $DATABASE_URL -f prod/migrations/0003_topology.up.sql
psql $DATABASE_URL -f prod/migrations/0004_agent_vitals.up.sql
psql $DATABASE_URL -f prod/migrations/0005_sessions.up.sql
```

**Option B — [golang-migrate](https://github.com/golang-migrate/migrate)**

```sh
migrate -path prod/migrations -database "$DATABASE_URL" up
```

Roll back all applied migrations:

```sh
migrate -path prod/migrations -database "$DATABASE_URL" down
```

Apply or roll back a specific number of steps:

```sh
migrate -path prod/migrations -database "$DATABASE_URL" up 2
migrate -path prod/migrations -database "$DATABASE_URL" down 1
```

> **Note:** golang-migrate requires paired `*.up.sql` / `*.down.sql` files. Only `*.up.sql` files exist in this repo. Add matching `*.down.sql` files for each migration before using `down` commands in production.

## Key concepts

### Multi-tenancy

Every piece of data is anchored to a `tenant`. Tenants are subdivided into `sections` (e.g. geographic regions). Tags, agents, endpoints and topologies are all section-scoped.

### Agent claiming

Agents self-register into `agent_claims` with a short-lived claim token. A user claims the agent via the UI, which moves it into the `agents` table and delivers an API key. The claim row is deleted once the key is delivered.

### Config versioning

`agents.config_version` is incremented automatically by triggers whenever anything the agent cares about changes (its own fields, its tags, the endpoints in its section, the topologies it participates in). Agents poll for config using this version as an ETag equivalent.

### Monitoring topology

A `topology` defines *which* agents monitor *which* endpoints using tag-based membership (`topology_members`). Three types are supported:

- **full-mesh** — every monitor-tagged agent pings every target-tagged endpoint
- **hub-and-spoke** — monitor agents ping target endpoints (one-directional)
- **one-way** — explicit source → destination, same semantics as hub-and-spoke

### Check results

Results are normalised: `check_results` holds the common fields; each check type has its own child table (`check_results_ping`, `check_results_http_get`, etc.). In production the base table is a TimescaleDB hypertable, so child tables do **not** carry a foreign key back to it (TimescaleDB limitation — enforced at the application layer instead).

### Agent vitals

Periodic host-resource snapshots (CPU, memory, uptime, check counters). Stored as a TimescaleDB hypertable in production. Suggested policies (tune to requirements):

```sql
SELECT add_retention_policy('agent_vitals', INTERVAL '30 days');
SELECT add_compression_policy('agent_vitals', INTERVAL '7 days');
```

### Sessions

Sessions are opaque-token based. The plaintext token is never stored — only its SHA-256 hash. Sessions have a sliding 7-day window capped by a hard 90-day expiry. IDP tokens are stored server-side and refreshed transparently.

## Code generation (sqlc)

`dev/sqlc/sqlc.yaml` points sqlc at the dev SQLite migrations and the shared query directory. After changing the schema run:

```sh
cd dev/sqlc
sqlc generate
```

See the [sqlc documentation](https://docs.sqlc.dev) for details.

## Further reading

- [Schema reference](schema.md) — full table/column reference with ER diagram
- [Dev vs prod differences](dev-vs-prod.md) — SQLite → PostgreSQL/TimescaleDB mapping
