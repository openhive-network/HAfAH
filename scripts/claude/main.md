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
   │  hive.blocks_view    hive.transactions_view    hive.operations_view │
   │  hive.accounts_view  hive.account_operations_view                   │
   │  hafd.operation_types                                                │
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

HAfAH reads from these HAF base tables:

| Table | Purpose |
|-------|---------|
| `hive.blocks_view` | Block headers |
| `hive.transactions_view` | Transaction data |
| `hive.operations_view` | Operation bodies |
| `hive.accounts_view` | Account name ↔ ID mapping |
| `hive.account_operations_view` | Account operation index |
| `hafd.operation_types` | Operation type metadata |

---

## Key Patterns

### 1. Reversibility Handling
```sql
-- Check if block is irreversible
SELECT hive.app_get_irreversible_block()

-- Set cache headers based on reversibility
-- Irreversible: 1 year cache
-- Reversible: 2 second cache
```

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
