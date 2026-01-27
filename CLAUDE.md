# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

HAfAH (HAF Account History) is a read-only HAF (Hive Application Framework) application that implements the account history API for the Hive blockchain. It's a PostgREST-based web server that responds to account history REST calls using data stored in a HAF database. Unlike other HAF apps, HAfAH requires no replay - it reads directly from base-layer HAF tables.

## Architecture

**Stack**: PostgreSQL + PostgREST (no application code - pure SQL functions exposed as REST API)

**Key directories**:
- `db/` - Database initialization
  - `builtin_roles.sql` - Database role definitions (hafah_owner, hafah_user)
  - `hafah_app.sql` - Schema creation, version table, helper views
- `backend/` - SQL implementation functions
  - `common/` - Shared utilities (json_utils, bit_operations, validation)
    - `utilities/` - REST-specific helpers (exceptions, validators, paging)
  - `rest/` - REST API backend functions (account_history, blocks, operations, market_history)
  - `jsonrpc/` - JSON-RPC API functions (argument_parsing, ops_in_block, transaction, virtual_ops, account_history, json_formatters)
- `endpoints/` - PostgREST-exposed API functions
  - `endpoint_schema.sql` - OpenAPI schema definition
  - `dispatcher.sql` - JSON-RPC router (home function)
  - `types/` - SQL type definitions
  - `accounts/`, `blocks/`, `operations/`, `transactions/`, `market_history/`, `operation_types/`, `other/` - REST endpoints
- `scripts/` - Setup and management scripts
- `tests/` - Integration tests (pytest) and REST API tests (tavern YAML)

**Database schemas** (only 2 schemas):
1. `hafah_backend` - Backend implementation functions, utilities, helper views, version table
2. `hafah_endpoints` - PostgREST-exposed API functions (the public interface)

**Database roles**:
- `haf_admin` - For install/uninstall operations
- `hafah_owner` - Schema owner (creates all objects)
- `hafah_user` - For running the PostgREST service (read-only, 10s query timeout)

## Common Commands

### Local Development

```bash
# Install app (with custom postgres URL)
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

# Run PostgREST server via Docker (internal port 6543 is fixed)
docker run --rm -it -p 8081:6543 -e POSTGRES_URL=postgresql://hafah_user@172.17.0.1:5432/haf_block_log registry.gitlab.syncad.com/hive/hafah:TAG
```

### Testing

```bash
# Run functional pytest tests (requires HAF + HAfAH running)
cd tests/integration/functional
pytest --junitxml report.xml --postgrest-hafah-adress=app:6543 --postgres-db-url=postgresql://haf_admin@haf-instance:5432/haf_block_log -m PYTEST_MARK

# Run tavern REST API tests (pattern tests against real blockchain data)
cd tests/tavern
pytest -n auto --junitxml report.xml .

# Run a single tavern test
pytest tests/tavern/get_block/positive/first_block.tavern.yaml

# Run performance tests (requires jmeter)
./tests/performance_test.py --postgres postgresql:///haf_block_log
```

Test marks: `enum_virtual_ops_and_get_ops_in_block`, `get_account_history_and_get_transaction`

## Dependency Management (Poetry)

The lockfile pins exact versions of all dependencies (direct and transitive). This prevents dependency mismatches between environments - if the lockfile is wrong or missing, builds may fail or behave differently. These rules keep it synchronized with pyproject.toml.

- **Dependency versions are specified in `pyproject.toml` and locked in `poetry.lock`**
- **Always use `poetry lock`** (without additional flags like `--regenerate`)
- **Always run `poetry lock` after changing `pyproject.toml`**
- **The `poetry.lock` file must be in the repository** - never add it to `.gitignore`
- **Never delete `poetry.lock`** - it ensures reproducible builds
- **Never edit `poetry.lock` manually** - always use poetry commands
- **Don't upgrade dependencies on your own** - only upgrade when explicitly requested

## API Call Styles

HAfAH supports two call styles:

**Old style (JSON-RPC via POST to /):**
```bash
curl -X POST http://localhost:3000/ \
  -H 'Content-Type: application/json' \
  -d '{"jsonrpc": "2.0", "method": "account_history_api.get_transaction", "params": {"id": "..."}, "id": 0}'
```

**New style (direct REST):**
```bash
curl -X POST http://localhost:3000/rpc/get_transaction \
  -H 'Content-Type: application/json' \
  -d '{"id": "..."}'
```

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

- No submodules - CI uses runtime cloning with sparse checkout for test tools
- HAF and Hive images are automatically detected via `find_haf_image` and `find_hive_image` jobs
- Pattern tests (tavern) are tied to specific blockchain data
- Uses cache-manager.sh from common-ci-configuration for HAF data caching
- NFS cache at `/nfs/ci-cache/haf/` shares HAF data across CI runners
- Docker image is Alpine-based (uses `apk`, `wget` - not `curl`)
- HAF scripts (common.sh, create_haf_app_role.sh) are fetched from common-ci-configuration at build time

**Hive Image Detection**: The `find_hive_image` job automatically detects the latest built Hive image from the develop branch using the `.find_upstream_image` template from `common-ci-configuration`. This eliminates manual tracking of Hive commits. The job:
- Extends `.find_upstream_image` template (same approach as clive)
- Fetches source patterns from hive's `source-patterns.sh` (single source of truth)
- Outputs `UPSTREAM_IMAGE`, `UPSTREAM_COMMIT`, etc. for downstream jobs
- Downstream jobs map these to `HIVED_IMAGE_NAME`, `HIVE_COMMIT` as needed

**Quick Test Mode**: Skip data preparation by setting `QUICK_TEST=true` and `QUICK_TEST_HAF_COMMIT=<sha>` in pipeline variables. Find available caches with:
```bash
ssh hive-builder-10 'ls -lt /nfs/ci-cache/haf/*.tar | head -5'
```

## SQL File Execution Order

SQL files are executed in specific order by `scripts/install_app.sh`:

1. **Database setup** (`db/`)
   - `db/builtin_roles.sql` - Create hafah_owner and hafah_user roles
   - `db/hafah_app.sql` - Create schemas, version table, helper views
   - `endpoints/endpoint_schema.sql` - OpenAPI schema

2. **Backend: Common utilities** (`backend/`)
   - `backend/jsonrpc/argument_parsing.sql` - JSON-RPC argument parsing
   - `backend/common/json_utils.sql` - JSON helper functions
   - `backend/common/bit_operations.sql` - Bit manipulation for filters
   - `backend/common/validation.sql` - Input validation

3. **Backend: JSON-RPC functions** (`backend/jsonrpc/`)
   - ops_in_block, transaction, virtual_ops, account_history, json_formatters

4. **Endpoint types** (`endpoints/types/`)
   - op_types, operation, sort_direction, block, transaction, fill_order, participation_mode

5. **Backend: REST utilities** (`backend/common/utilities/`)
   - exceptions, validators, account, get_operation_types, paging, path_filters, operation_body_filter, function_helpers

6. **Backend: REST implementations** (`backend/rest/`)
   - account_history/, market_history/, blocks/, operations/

7. **JSON-RPC dispatcher**
   - `endpoints/dispatcher.sql` - Main router (home function)
   - `scripts/set_version_in_sql.pgsql` - Version injection

8. **REST endpoints** (`endpoints/`)
   - blocks/, transactions/, accounts/, operations/, operation_types/, other/, market_history/

9. **Permissions** (inline in install_app.sh)
   - GRANT USAGE on schemas to hafah_user
   - GRANT SELECT on tables to hafah_user
   - GRANT EXECUTE on functions to hafah_user
   - Create is_setup_completed() function

## Development Notes

- All API logic is in SQL - no Python/application code for the main service
- PostgREST exposes `hafah_endpoints` schema functions as REST endpoints
- The `hafah_endpoints.home()` function is the main JSON-RPC dispatcher
- Backend functions live in `hafah_backend` schema (single backend schema)
- `test_tools` is installed as wheel from GitLab package registry; `haf_local_tools` is cloned at runtime in CI via sparse checkout
- The `hafah_backend.helper_operations_view` joins `hive.operations_view` with operation types
