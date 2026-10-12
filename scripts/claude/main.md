# HAfAH Architecture Overview

## What is HAfAH?

HAfAH (HAF Account History) is a **read-only** HAF application that implements the account history API for Hive blockchain. Unlike other HAF apps, HAfAH requires no replay - it reads directly from base-layer HAF tables.

**Key Characteristics:**
- Pure SQL implementation (no application code)
- PostgreSQL + PostgREST stack
- Two API styles: JSON-RPC 2.0 and REST
- Zero writes to database (read-only)

---

## Architecture Diagram

```
                              ┌─────────────────────┐
                              │   HTTP Clients      │
                              └──────────┬──────────┘
                                         │
              ┌──────────────────────────┼──────────────────────────┐
              │                          │                          │
              ▼                          ▼                          ▼
   ┌──────────────────┐      ┌──────────────────┐      ┌──────────────────┐
   │ POST /           │      │ POST /rpc/{fn}   │      │ GET /accounts/   │
   │ (JSON-RPC 2.0)   │      │ (PostgREST RPC)  │      │ (REST endpoints) │
   └────────┬─────────┘      └────────┬─────────┘      └────────┬─────────┘
            │                         │                          │
            │                         │                          │
            ▼                         ▼                          ▼
   ┌─────────────────────────────────────────────────────────────────────┐
   │                      PostgREST                                       │
   │                 (HTTP → SQL translation)                             │
   └─────────────────────────────┬───────────────────────────────────────┘
                                 │
                                 ▼
   ┌─────────────────────────────────────────────────────────────────────┐
   │                    hafah_endpoints schema                            │
   │              (PostgREST-exposed functions)                           │
   │                                                                      │
   │  ┌─────────────┐  ┌─────────────────┐  ┌──────────────────────────┐ │
   │  │ home()      │  │ get_block()     │  │ get_ops_by_account()     │ │
   │  │ (JSON-RPC   │  │ get_block_*()   │  │ get_transaction()        │ │
   │  │  dispatcher)│  │ get_ops_*()     │  │ get_op_types()           │ │
   │  └──────┬──────┘  └────────┬────────┘  └────────────┬─────────────┘ │
   └─────────┼──────────────────┼────────────────────────┼───────────────┘
             │                  │                        │
             ▼                  ▼                        ▼
   ┌─────────────────────────────────────────────────────────────────────┐
   │                    hafah_backend schema                              │
   │                 (Implementation functions)                           │
   │                                                                      │
   │  ┌─────────────────┐  ┌─────────────────┐  ┌────────────────────┐   │
   │  │ jsonrpc/        │  │ rest/           │  │ utilities/         │   │
   │  │ - methods/      │  │ - blocks/       │  │ - validators       │   │
   │  │ - formatters/   │  │ - operations/   │  │ - exceptions       │   │
   │  │ - arg_parsing   │  │ - account_hist/ │  │ - paging           │   │
   │  └────────┬────────┘  └────────┬────────┘  └─────────┬──────────┘   │
   └───────────┼────────────────────┼─────────────────────┼──────────────┘
               │                    │                     │
               └────────────────────┼─────────────────────┘
                                    │
                                    ▼
   ┌─────────────────────────────────────────────────────────────────────┐
   │                      HAF Base Tables                                 │
   │                                                                      │
   │  hafd.blocks         hafd.transactions         hafd.operations     │
   │  hafd.accounts       hafd.account_operations   hafd.operation_types │
   │  (irreversible data only, bounded by app_get_irreversible_block())  │
   └─────────────────────────────────────────────────────────────────────┘
```

---

## Two-Schema Architecture

HAfAH uses exactly **two schemas**:

| Schema | Purpose | Contains |
|--------|---------|----------|
| `hafah_endpoints` | Public API surface | PostgREST-exposed functions (thin wrappers) |
| `hafah_backend` | Implementation layer | All business logic, utilities, formatters |

**Why two schemas?**
- PostgREST exposes only `hafah_endpoints` to HTTP clients
- Internal functions in `hafah_backend` are not directly callable via HTTP
- Clear separation between API contract and implementation

---

## Database Roles

| Role | Purpose | Permissions |
|------|---------|-------------|
| `haf_admin` | Installation/uninstallation | Creates schemas and roles |
| `hafah_owner` | Schema owner | Creates all database objects |
| `hafah_user` | PostgREST runtime | Read-only, 10-second query timeout |

---

## Directory Structure

```
hafah/
├── db/                          # Database initialization
│   ├── builtin_roles.sql        # Role definitions
│   └── hafah_app.sql            # Schema creation, version table
├── backend/                     # Implementation functions
│   ├── utilities/               # Shared utilities (both APIs)
│   ├── jsonrpc/                 # JSON-RPC 2.0 backend
│   │   ├── argument_parsing.sql
│   │   ├── formatters/          # Response formatters
│   │   └── methods/             # Method implementations
│   └── rest/                    # REST API backend
│       ├── helpers/
│       ├── account_history/     # Router + 6 filter implementations
│       ├── blocks/
│       ├── operations/
│       └── market_history/
├── endpoints/                   # PostgREST-exposed functions
│   ├── dispatcher.sql           # JSON-RPC router
│   ├── endpoint_schema.sql      # OpenAPI schema
│   ├── types/                   # SQL type definitions
│   └── {resource}/              # REST endpoint wrappers
└── scripts/                     # Setup and management
```

---

## SQL File Execution Order

Installation executes files in this specific order (see `scripts/install_app.sh`):

1. **Database setup** - `db/builtin_roles.sql`, `db/hafah_app.sql`
2. **OpenAPI schema** - `endpoints/endpoint_schema.sql`
3. **Endpoint types** - `endpoints/types/*.sql`
4. **Shared utilities** - `backend/utilities/*.sql`
5. **JSON-RPC backend** - `backend/jsonrpc/argument_parsing.sql`, formatters, methods
6. **REST backend helpers** - `backend/rest/helpers/*.sql`
7. **REST backend implementations** - `backend/rest/{resource}/*.sql`
8. **JSON-RPC dispatcher** - `endpoints/dispatcher.sql`
9. **REST endpoints** - `endpoints/{resource}/*.sql`
10. **Permissions** - GRANT statements for hafah_user

---

## Naming Conventions

### Variable Prefixes
- `_var` - Function parameters (single underscore)
- `__var` - Function-local variables in DECLARE (double underscore)

### Function Naming
- `hafah_backend.get_*` - REST backend functions
- `hafah_backend.ah_*` - Account history functions
- `hafah_backend.*_json` - Functions returning JSON
- `hafah_endpoints.*` - PostgREST-exposed functions

---

## HAF Table Dependencies

HAfAH serves **irreversible data only** and reads the `hafd.*` base tables
directly, never the `hive.*_view` views or the `hafd.*_reversible` tables:

| Table | Purpose |
|-------|---------|
| `hafd.blocks` | Block headers |
| `hafd.transactions` | Transaction data |
| `hafd.transactions_multisig` | Additional transaction signatures |
| `hafd.operations` | Operation bodies (`body_value`; block encoded in `id`) |
| `hafd.accounts` | Account name ↔ ID mapping |
| `hafd.account_operations` | Account operation index |
| `hafd.operation_types` | Operation type metadata |

Every query is bounded by `hive.app_get_irreversible_block()`. The JSON-RPC
`include_reversible` and REST `include-reversible` arguments are still accepted
so clients do not break, but they do not change the result: even when set to
true, only irreversible blocks and operations are returned.

`hafah_backend.helper_operations_view` (`db/hafah_app.sql`) joins
`hafd.operations` with `hafd.operation_types` and builds the operation body
exactly as `hive.operations_view` does (`{"type": ..., "value": body_value}`).
Use it for the single per-row operations join.

HAF functions without a base-table variant are still called and guarded by an
irreversible-block check first: `hive.get_block`, `hive.get_block_header`,
`hive.get_block_from_views` (block endpoints) and `hive.convert_to_blocks_range`
(timestamp → block number).

---

## Key Patterns

### 1. Irreversible Data Only
```sql
-- Last block whose data is served
SELECT hive.app_get_irreversible_block()

-- Block bound on operation ids: every operation of block N has
-- operation_id(N, 0) <= id < operation_id(N + 1, 0)
WHERE ao.operation_id < hafd.operation_id(hive.app_get_irreversible_block() + 1, 0)

-- Cache headers
-- Irreversible: 1 year cache
-- Range reaching past the irreversible block: 2 second cache (data appears later)
```

Account history functions with an operation-type filter set
`plan_cache_mode = force_custom_plan`, so each call is planned with its account
and filter: walking `hive_account_operations_uq1` backwards wins when the
requested types are common for the account, the `(account_id, op_type_id)`
index wins when they are rare. Every filtered path (JSON-RPC `get_account_history`,
REST `by_operations` and the include/exclude-account variants) counts the
matches in the range its page reads, up to `sqrt(rows * N)`
(`hafah_backend.account_op_types_are_rare`, or the exact total in
`by_operations`), and runs one of two `UNION ALL` branches accordingly. The
include variants filter on `transacting_account_id`, which the type index lacks,
so their count (`hafah_backend.account_rare_op_matches`) reads the heap rows and
returns them when rare; the rare branch sorts those instead of reading again.

### 2. Binary to Hex Encoding
```sql
-- Block hashes, transaction IDs, signatures
encode(block_id, 'hex')::TEXT
```

### 3. Pagination (Descending Order)
```sql
-- Page 1 = most recent, descending order
-- Special offset calculation for remainder on first page
```

### 4. IEEE 754 Safe Integers
```sql
-- JSON numbers > 2^53-1 become strings
hafah_backend.json_stringify_bigint(_value)
```

---

## Expansion Rules

When modifying HAfAH:

| Change Type | Update |
|-------------|--------|
| New JSON-RPC method | `scripts/claude/jsonrpc.md` |
| New REST endpoint | `scripts/claude/rest.md` |
| New utility function | `scripts/claude/utilities.md` |
| New tests | `scripts/claude/tests.md` |
| Architecture changes | This file (`main.md`) |

Always ensure cross-references remain valid after changes.
