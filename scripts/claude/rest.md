# REST API

## Overview

HAfAH provides direct REST endpoints for querying blockchain data. All endpoints are exposed via PostgREST from the `hafah_endpoints` schema.

---

## Endpoint Categories

| Category | Base Path | Description |
|----------|-----------|-------------|
| Blocks | `/blocks/` | Block data and headers |
| Transactions | `/transactions/` | Transaction lookup |
| Accounts | `/accounts/` | Account operation history |
| Operations | `/operations/` | Operation queries |
| Operation Types | `/operation-types/` | Operation type metadata |
| Market History | `/market-history/` | Trade data |
| Other | `/version`, `/head-block` | Utility endpoints |

---

## Endpoint Reference

### Blocks

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/blocks/{block-num}` | GET | Full block with transactions |
| `/blocks/{block-num}/header` | GET | Block header only |
| `/blocks/{block-num}/operations` | GET | Operations in block |
| `/blocks?from-block&to-block` | GET | Block range |

### Transactions

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/transactions/{transaction-id}` | GET | Transaction by hash |

### Accounts

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/accounts/{account-name}/operations` | GET | Account operation history |

**Query Parameters:**
- `page` - Page number (default: 1)
- `page-size` - Results per page (default: 100, max: 1000)
- `operation-types` - Filter by operation type IDs
- `account-filter` - Filter by transacting account
- `participation-mode` - `include` or `exclude` account filter

### Operations

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/operations?from-block&to-block` | GET | Search operations |
| `/operations/virtual?from-block&to-block` | GET | Virtual operations |

### Operation Types

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/operation-types` | GET | List all operation types |

### Market History

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/market-history/recent-trades` | GET | Recent market trades |
| `/market-history/trades?from-block&to-block` | GET | Historical trades |

### Other

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/version` | GET | API version |
| `/head-block` | GET | Current head block |

---

## Account History Router

The account history endpoint uses a **router pattern** to select optimal query strategy based on filters.

**Main Entry Point:** `backend/rest/account_history/router.sql`

### Routing Logic

```
get_ops_by_account()
        │
        ├─ Has operation filter only? → by_operations.sql
        │
        ├─ Has single include account? → include_account.sql
        │
        ├─ Has multiple include accounts? → including_accounts.sql
        │
        ├─ Has single exclude account? → exclude_account.sql
        │
        ├─ Has multiple exclude accounts? → excluding_accounts.sql
        │
        └─ No filters? → default.sql
```

### Filter Implementations

| File | Strategy | When Used |
|------|----------|-----------|
| `default.sql` | Simple query | No filters |
| `by_operations.sql` | Type filter only | `operation-types` param |
| `include_account.sql` | Include 1 account | `account-filter` + `include` |
| `including_accounts.sql` | Include N accounts | `account-filter[]` + `include` |
| `exclude_account.sql` | Exclude 1 account | `account-filter` + `exclude` |
| `excluding_accounts.sql` | Exclude N accounts | `account-filter[]` + `exclude` |

**Why Separate Implementations?**
Each filter strategy requires different JOIN patterns for optimal performance. A single function with conditional logic would produce suboptimal query plans.

---

## Pagination

REST endpoints use **descending order pagination**:
- Page 1 = most recent results
- Higher page numbers = older results

### Calculation Logic

```sql
-- Total pages
total_pages = CEIL(total_count / page_size)

-- Offset for descending order
-- Page 1 with remainder gets special handling
offset = (total_pages - page) * page_size
```

**File:** `backend/utilities/paging.sql`

---

## Cache Headers

HAfAH sets cache headers based on data reversibility:

| Data State | Cache Duration | Reason |
|------------|----------------|--------|
| Irreversible | 1 year (31536000s) | Data will never change |
| Reversible | 2 seconds | Data may be forked |

**Check Function:**
```sql
hive.app_get_irreversible_block()
```

---

## Block Endpoints Implementation

Located in `backend/rest/blocks/`:

| File | Function | HAF Tables Used |
|------|----------|-----------------|
| `block.sql` | `get_block()` | blocks_view, transactions_view, operations_view |
| `block_header.sql` | `get_block_header()` | blocks_view |
| `block_range.sql` | `get_block_range()` | blocks_view |

---

## Operation Endpoints Implementation

Located in `backend/rest/operations/`:

| File | Function | Purpose |
|------|----------|---------|
| `operation.sql` | `get_operation()` | Single operation by ID |
| `ops_in_block.sql` | `get_ops_by_block()` | Operations in one block |
| `op_types.sql` | `get_op_types()` | Operation type list |
| `acc_op_types.sql` | `get_acc_op_types()` | Types for account |

---

## Market History Implementation

Located in `backend/rest/market_history/`:

| File | Function | Purpose |
|------|----------|---------|
| `recent_trades.sql` | `recent_trades()` | Recent fill orders |
| `trade_history.sql` | `trade_history()` | Historical trades |

---

## Key Patterns

### Operation Type Filtering
```sql
-- Array containment operator <@
WHERE op.op_type_id = ANY(_operation_types)
```

### Binary Encoding
```sql
-- Hashes and signatures returned as hex strings
encode(trx_hash, 'hex')::TEXT
```

### Missing Block Handling
```sql
-- Returns error response for missing blocks
PERFORM hafah_backend.rest_raise_block_num_too_high(_block_num);
```

---

## Key Files

| File | Purpose |
|------|---------|
| `endpoints/accounts/get_ops_by_account.sql` | Account history endpoint |
| `endpoints/blocks/*.sql` | Block endpoints |
| `endpoints/transactions/*.sql` | Transaction endpoints |
| `endpoints/operations/*.sql` | Operation endpoints |
| `backend/rest/account_history/router.sql` | Account history routing |
| `backend/rest/blocks/*.sql` | Block implementations |
| `backend/rest/operations/*.sql` | Operation implementations |

---

## Expansion Rules

When adding a new REST endpoint:

1. Add backend implementation in `backend/rest/{category}/`
2. Add endpoint wrapper in `endpoints/{category}/`
3. Add OpenAPI documentation in `endpoints/endpoint_schema.sql`
4. Update this documentation
