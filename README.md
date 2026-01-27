# HAfAH - HAF Account History

HAfAH is a **read-only** HAF application that implements the account history API for the Hive blockchain. It's a PostgREST-based web server that responds to account history REST calls using data stored in a [HAF database](https://gitlab.syncad.com/hive/haf).

## Features

- **Two API styles**: JSON-RPC 2.0 and direct REST endpoints
- **No replay required**: Reads directly from HAF base tables
- **Pure SQL**: All logic is implemented in PostgreSQL functions
- **High performance**: Optimized queries with proper caching

## Quick Start (Docker)

### 1. Install the application

```bash
docker run --rm -it registry.gitlab.syncad.com/hive/hafah:latest \
  install_app --postgres-url=postgresql://haf_admin@172.17.0.1:5432/haf_block_log
```

### 2. Run the server

```bash
docker run --rm -it -p 8081:6543 \
  -e POSTGRES_URL=postgresql://hafah_user@172.17.0.1:5432/haf_block_log \
  registry.gitlab.syncad.com/hive/hafah:latest
```

The API is now available at `http://localhost:8081`.

## API Examples

### REST API

```bash
# Get block
curl http://localhost:8081/blocks/1

# Get account history
curl "http://localhost:8081/accounts/blocktrades/operations?page-size=10"

# Get transaction
curl http://localhost:8081/transactions/ef73d8fadf17e2590c6d96efc1ca868edd7dd613

# API version
curl http://localhost:8081/version
```

### JSON-RPC API

```bash
curl -X POST http://localhost:8081/ \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "method": "account_history_api.get_account_history",
    "params": {"account": "blocktrades", "start": -1, "limit": 10},
    "id": 0
  }'
```

## REST Endpoints

| Endpoint | Description |
|----------|-------------|
| `/blocks/{block-num}` | Get block details |
| `/blocks/{block-num}/header` | Get block header |
| `/blocks/{block-num}/operations` | Operations in block |
| `/blocks?from-block&to-block` | Get block range |
| `/transactions/{tx-id}` | Get transaction |
| `/accounts/{name}/operations` | Account history |
| `/operations?from-block&to-block` | Search operations |
| `/operation-types` | List operation types |
| `/version` | API version |

## JSON-RPC Methods

| Method | Description |
|--------|-------------|
| `account_history_api.get_account_history` | Get account operation history |
| `account_history_api.get_transaction` | Get transaction by hash |
| `account_history_api.get_ops_in_block` | Get operations in block |
| `account_history_api.enum_virtual_ops` | Enumerate virtual operations |
| `block_api.get_block` | Get full block |
| `block_api.get_block_header` | Get block header |
| `block_api.get_block_range` | Get multiple blocks |

## Installation Options

### Option 1: Docker (Recommended)

See [Quick Start](#quick-start-docker) above.

### Option 2: Direct Installation

```bash
# Install
./scripts/install_app.sh --postgres-url=postgresql://haf_admin@localhost:5432/haf_block_log

# Run PostgREST (requires PostgREST installed)
./run.sh start 3000
```

## PostgreSQL Authentication

If you're running PostgreSQL directly (not in Docker), configure authentication:

**pg_hba.conf:**
```
host    haf_block_log    haf_admin     172.0.0.0/0    trust
host    haf_block_log    hafah_user    172.0.0.0/0    trust
```

**postgresql.conf:**
```
listen_addresses = '172.17.0.1'  # or '*' for all interfaces
```

> **Warning**: The above configuration is for testing only. For production, use proper authentication methods.

## Building from Source

```bash
scripts/ci-helpers/build_instance.sh "postgrest-latest" . registry.gitlab.syncad.com/hive/hafah \
  --http-port=80 \
  --haf-postgres-url=postgresql://haf_admin@haf-instance:5432/haf_block_log
```

## Testing

```bash
# REST API tests (Tavern)
cd tests/tavern
pytest -n auto .

# Performance tests (requires JMeter)
./tests/performance_test.py --postgres postgresql:///haf_block_log
```

## Architecture

```
┌─────────────┐
│ HTTP Client │
└──────┬──────┘
       │
┌──────▼──────┐
│  PostgREST  │
└──────┬──────┘
       │
┌──────▼──────────────────┐
│  hafah_endpoints schema │  (Public API)
└──────┬──────────────────┘
       │
┌──────▼──────────────────┐
│  hafah_backend schema   │  (Implementation)
└──────┬──────────────────┘
       │
┌──────▼──────────────────┐
│  HAF Base Tables        │  (hive.*, hafd.*)
└─────────────────────────┘
```

## License

See [LICENSE](LICENSE) file.

## Links

- [HAF Block Explorer](https://gitlab.syncad.com/hive/hafbe) (parent project)
- [HAF](https://gitlab.syncad.com/hive/haf) (Hive Application Framework)
- [Hive](https://hive.io) (Hive blockchain)
