# JSON-RPC 2.0 API

## Overview

HAfAH implements the Hive account history API using JSON-RPC 2.0 protocol. Requests are sent as POST to `/` with a JSON envelope.

---

## Supported Methods

| API Namespace | Method | Description |
|---------------|--------|-------------|
| `account_history_api` | `get_account_history` | Get operation history for an account |
| `account_history_api` | `get_ops_in_block` | Get operations in a specific block |
| `account_history_api` | `enum_virtual_ops` | Enumerate virtual operations in block range |
| `account_history_api` | `get_transaction` | Get transaction by hash |
| `block_api` | `get_block` | Get full block with transactions |
| `block_api` | `get_block_header` | Get block header only |
| `block_api` | `get_block_range` | Get multiple blocks |
| `hive_api` | `get_version` | Get API version |

**Legacy Support:** Methods prefixed with `condenser_api.*` are also supported for backwards compatibility.

---

## Request Format

```json
{
  "jsonrpc": "2.0",
  "method": "account_history_api.get_account_history",
  "params": {
    "account": "blocktrades",
    "start": -1,
    "limit": 100
  },
  "id": 0
}
```

**Two Parameter Styles:**
- **Object style**: `{"account": "blocktrades", "start": -1, "limit": 100}`
- **Array style**: `["blocktrades", -1, 100]`

---

## Response Format

**Success:**
```json
{
  "jsonrpc": "2.0",
  "result": {
    "history": [
      [12345, {"trx_id": "...", "block": 1000, "op": [...], ...}]
    ]
  },
  "id": 0
}
```

**Error:**
```json
{
  "jsonrpc": "2.0",
  "error": {
    "code": -32602,
    "message": "Invalid params",
    "data": "Account not found"
  },
  "id": 0
}
```

---

## Dispatcher Flow

The `hafah_endpoints.home()` function routes JSON-RPC requests:

```
POST / with JSON body
        │
        ▼
home(_body JSON)
        │
        ├─ Parse method string (e.g., "account_history_api.get_transaction")
        │
        ├─ Route to call_* function based on method
        │   ├─ call_get_account_history()
        │   ├─ call_get_ops_in_block()
        │   ├─ call_enum_virtual_ops()
        │   ├─ call_get_transaction()
        │   ├─ call_get_block()
        │   ├─ call_get_block_header()
        │   ├─ call_get_block_range()
        │   └─ call_get_version()
        │
        └─ Return JSON-RPC response
```

**File:** `endpoints/dispatcher.sql`

---

## Argument Parsing

Located in `backend/jsonrpc/argument_parsing.sql`:

### Key Functions

| Function | Purpose |
|----------|---------|
| `parse_argument()` | Extract parameter from object or array style params |
| `parse_acc_hist_start()` | Handle negative start values (negative = from end) |
| `parse_acc_hist_limit()` | Handle unsigned integer wraparound |
| `json_stringify_bigint()` | Convert BIGINT respecting IEEE 754 safe range |
| `numeric_to_bigint()` | Handle two's complement overflow |

### Negative Start Values

In `get_account_history`, negative start values mean "from the end":
- `start: -1` → Most recent operation
- `start: -100` → 100th most recent operation

### 128-bit Filter Bitmask

Operation type filters use a 128-bit bitmask split into two 64-bit integers:
```sql
-- filter_low: bits 0-63 (operation types 0-63)
-- filter_high: bits 64-127 (operation types 64-127)
hafah_backend.translate_get_account_history_filter(_filter_low, _filter_high)
```

---

## Method Implementations

Located in `backend/jsonrpc/methods/`:

| File | Function | Notes |
|------|----------|-------|
| `account_history.sql` | `ah_get_account_history()` | Core account history query |
| `transaction.sql` | `get_transaction()` | Single transaction lookup |
| `ops_in_block.sql` | `get_ops_in_block()` | All operations in block |
| `virtual_ops.sql` | `enum_virtual_ops()` | Virtual ops in block range |

---

## Response Formatters

Located in `backend/jsonrpc/formatters/`:

| File | Function | Output |
|------|----------|--------|
| `account_history.sql` | `ah_get_account_history_json()` | `{history: [[seq, op], ...]}` |
| `transaction.sql` | `get_transaction_json()` | Transaction with operations |
| `ops_in_block.sql` | `get_ops_in_block_json()` | `{ops: [...]}` |
| `virtual_ops.sql` | `enum_virtual_ops_json()` | `{ops: [...], next_block_range_begin: N}` |

### Legacy vs New Style

- **New style** (`account_history_api.*`): Returns `{history: [[seq, {op}], ...]}`
- **Legacy style** (`condenser_api.*`): Returns `[[seq, {op_without_operation_id}], ...]`

---

## Error Response Format

| Code | Message | Meaning |
|------|---------|---------|
| -32700 | Parse error | Invalid JSON |
| -32600 | Invalid Request | Invalid JSON-RPC structure |
| -32601 | Method not found | Unknown method name |
| -32602 | Invalid params | Parameter validation failed |
| -32603 | Internal error | Server error |

**Exception Functions** (`backend/jsonrpc/exception_parsing.sql`):
- `raise_exception()` - Generic error
- `raise_uint_exception()` - Unsigned integer expected
- `raise_int32_exception()` - 32-bit integer overflow
- `raise_missing_*_exception()` - Required parameter missing

---

## Key Files

| File | Purpose |
|------|---------|
| `endpoints/dispatcher.sql` | Main router (home function) |
| `backend/jsonrpc/argument_parsing.sql` | Parameter extraction and validation |
| `backend/jsonrpc/exception_parsing.sql` | Error response formatting |
| `backend/jsonrpc/methods/*.sql` | Core method implementations |
| `backend/jsonrpc/formatters/*.sql` | Response JSON construction |

---

## Expansion Rules

When adding a new JSON-RPC method:

1. Add method implementation in `backend/jsonrpc/methods/`
2. Add formatter in `backend/jsonrpc/formatters/` if needed
3. Add `call_*` wrapper in `endpoints/dispatcher.sql`
4. Add routing case in `home()` function
5. Update this documentation
