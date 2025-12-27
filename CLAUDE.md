# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HAfAH (HAF Account History) is a read-only HAF (Hive Application Framework) application that implements the account history API for the Hive blockchain. It's a PostgREST-based web server that responds to account history REST calls using data stored in a HAF database. Unlike other HAF apps, HAfAH requires no replay - it reads directly from base-layer HAF tables.

## Architecture

**Stack**: PostgreSQL + PostgREST (no application code - pure SQL functions exposed as REST API)

**Key directories**:
- `postgrest/` - PostgREST endpoint definitions and SQL types
  - `hafah_endpoints.sql` - Main API endpoint registration
  - `hafah_REST/` - REST endpoint SQL functions organized by resource (blocks, accounts, operations, transactions)
- `queries/` - Backend SQL functions
  - `ah_schema_functions.pgsql` - Core schema and helper functions
  - `hafah_rest_backend/` - Implementation functions for each API
- `scripts/` - Setup and management scripts
- `tests/` - Integration tests (pytest) and REST API tests (tavern YAML)
- `haf/` - HAF submodule (the underlying data framework)

**Database roles**:
- `haf_admin` - For install/uninstall operations
- `hafah_user` - For running the PostgREST service
- `hafah_owner` - Schema owner for hafah_python

## Common Commands

### Local Development

```bash
# Setup database and install app (requires running HAF database)
./run.sh setup

# Start PostgREST server (default port 3000)
./run.sh start [PORT]

# Install app only (with custom postgres URL)
scripts/install_app.sh --postgres-url=postgresql://haf_admin@localhost:5432/haf_block_log

# Uninstall app
scripts/uninstall_app.sh --postgres-url=postgresql://haf_admin@localhost:5432/haf_block_log
```

### Docker

```bash
# Build Docker image
scripts/ci-helpers/build_instance.sh "postgrest-latest" . registry.gitlab.syncad.com/hive/hafah

# Install app via Docker
docker run --rm -it registry.gitlab.syncad.com/hive/hafah:TAG install_app --postgres-url=postgresql://haf_admin@172.17.0.1:5432/haf_block_log

# Run PostgREST server via Docker
docker run --rm -it -p 8081:6543 -e POSTGRES_URL=postgresql://hafah_user@172.17.0.1:5432/haf_block_log registry.gitlab.syncad.com/hive/hafah:TAG
```

### Testing

```bash
# Run functional pytest tests (requires HAF + HAfAH running)
cd tests/integration/functional
pytest --junitxml report.xml --postgrest-hafah-adress=app:6543 --postgres-db-url=postgresql://haf_admin@haf-instance:5432/haf_block_log -m PYTEST_MARK

# Run tavern REST API tests
cd tests/tavern
pytest -n auto --junitxml report.xml .

# Run performance tests (requires jmeter)
./tests/performance_test.py --postgres postgresql:///haf_block_log
```

Test marks: `enum_virtual_ops_and_get_ops_in_block`, `get_account_history_and_get_transaction`

## REST API Endpoints

- `/blocks/{block-num}` - Get block details
- `/blocks/{block-num}/header` - Get block header
- `/blocks?from-block&to-block` - Get block range
- `/blocks/{block-num}/operations` - Operations in block
- `/transactions/{transaction-id}` - Get transaction
- `/accounts/{account-name}/operations` - Account history
- `/operations?from-block&to-block` - Search operations
- `/operation-types` - List operation types
- `/version` - API version

## CI/CD Notes

- HAF submodule commit must match in three places: `.gitmodules` ref, `HAF_COMMIT` variable in `.gitlab-ci.yml`, and `include: ref:` in `.gitlab-ci.yml`
- The `validate_haf_commit` job ensures these stay in sync
- Pattern tests are tied to specific blockchain data and may fail when HAF commit changes
- Uses NFS cache at `/nfs/ci-cache/haf/` for HAF data across CI runners

## Development Notes

- All API logic is in SQL - no Python/application code for the main service
- PostgREST exposes `hafah_endpoints` schema functions as REST endpoints
- Backend functions live in `hafah_python` and `hafah_backend` schemas
- SQL files are executed in specific order by `scripts/install_app.sh`
- Test tools from HAF submodule: `test_tools`, `haf_local_tools`
