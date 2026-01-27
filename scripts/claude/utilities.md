# Utilities Reference

## Overview

Shared utility functions used by both JSON-RPC and REST APIs. Located in `backend/utilities/`.

---

## Utility Files

| File | Functions | Purpose |
|------|-----------|---------|
| `helpers.sql` | `is_block_missing()`, `is_path_filter_not_empty()`, `get_group_type()` | REST-specific helpers |
| `validators.sql` | `validate_*()` | Input validation (12 functions) |
| `exceptions.sql` | `rest_raise_*()`, `raise_*()` | Error handling |
| `account.sql` | `get_account_id()`, `get_account_name()` | Account lookup |
| `operation_types.sql` | `get_operation_types()`, `get_group_type()` | Operation type parsing |
| `paging.sql` | `calculate_pages()`, `account_range()`, `total_pages()` | Pagination logic |
| `path_filters.sql` | `decode_param()`, `parse_path_filters()` | URL parameter parsing |
| `operation_body_filter.sql` | `operation_body_filter()`, `body_filter_*()` | Truncate large bodies |
| `bit_operations.sql` | `get_bit_positions_*()`, `translate_*_filter()` | Filter bitmask translation |
| `json_utils.sql` | `json_stringify_bigint()`, `numeric_to_bigint()` | JSON number handling |

---

## Validators (`validators.sql`)

Input validation functions that normalize and bounds-check parameters.

| Function | Purpose | Returns |
|----------|---------|---------|
| `validate_limit()` | Check limit within bounds | Validated limit |
| `validate_page()` | Check page number ≥ 1 | Validated page |
| `validate_block_num()` | Check block number valid | Validated block |
| `validate_from_block()` | Check from_block | Validated from |
| `validate_to_block()` | Check to_block > from_block | Validated to |
| `validate_operation_types()` | Parse operation type list | INT[] array |
| `validate_account_name()` | Check account exists | Account ID |

**Pattern:**
```sql
/*
 * validate_limit: Validates and normalizes limit parameter.
 *
 * RULES:
 *   - If NULL or 0, use default
 *   - If negative, raise error
 *   - If exceeds max, cap at max
 */
```

---

## Exceptions (`exceptions.sql`)

### REST Exceptions

| Function | HTTP Status | When Used |
|----------|-------------|-----------|
| `rest_raise_missing_block()` | 404 | Block not found |
| `rest_raise_missing_account()` | 404 | Account not found |
| `rest_raise_block_num_too_high()` | 404 | Block beyond head |
| `rest_raise_invalid_operation_type()` | 400 | Unknown op type |
| `rest_raise_invalid_participation_mode()` | 400 | Invalid filter mode |

### JSON-RPC Exceptions

| Function | Error Code | When Used |
|----------|------------|-----------|
| `raise_exception()` | varies | Generic error |
| `raise_uint_exception()` | -32602 | Expected unsigned int |
| `raise_int32_exception()` | -32602 | 32-bit overflow |
| `raise_missing_account_exception()` | -32602 | Required param missing |

---

## Account Lookup (`account.sql`)

| Function | Purpose |
|----------|---------|
| `get_account_id(_name)` | Convert account name to ID |
| `get_account_name(_id)` | Convert account ID to name |

**Source:** `hive.accounts_view`

**Note:** Account lookup should be done on the smallest/most-filtered result set (late binding) for performance.

---

## Operation Types (`operation_types.sql`)

| Function | Purpose |
|----------|---------|
| `get_operation_types(_filter)` | Parse operation type string to INT[] |
| `get_group_type(_filter)` | Determine filter group (virtual/non-virtual/all) |

**Input Format:** Comma-separated type IDs: `"0,1,5,10"`

**Source:** `hafd.operation_types`

---

## Pagination (`paging.sql`)

| Function | Purpose |
|----------|---------|
| `total_pages(_count, _limit)` | Calculate total page count |
| `calculate_pages(_total, _page, _limit)` | Get offset for descending pagination |
| `account_range(_page, _limit, _total)` | Get operation sequence range |

### Descending Pagination Logic

```sql
-- Page 1 = most recent (highest sequence numbers)
-- Page N = oldest

-- Calculate offset for descending order
__total_pages := CEIL(__total_count::NUMERIC / _limit);
__offset := (__total_pages - _page) * _limit;

-- Handle remainder on first page
IF _page = 1 AND (__total_count % _limit) != 0 THEN
  __offset := 0;
  __actual_limit := __total_count % _limit;
END IF;
```

---

## Path Filters (`path_filters.sql`)

URL parameter parsing for REST endpoints.

| Function | Purpose |
|----------|---------|
| `decode_param(_param)` | URL decode parameter |
| `parse_path_filters(_path)` | Extract filters from URL path |

---

## Operation Body Filter (`operation_body_filter.sql`)

Truncate large operation bodies to prevent response size issues.

| Function | Purpose |
|----------|---------|
| `operation_body_filter(_body, _limit)` | Truncate body if > limit |
| `body_filter_should_truncate(_body)` | Check if truncation needed |
| `body_filter_truncate(_body)` | Apply truncation |

**Default Limit:** 1MB

---

## Bit Operations (`bit_operations.sql`)

Translate 128-bit filter bitmask to operation type IDs.

| Function | Purpose |
|----------|---------|
| `get_bit_positions_low(_filter)` | Get type IDs from bits 0-63 |
| `get_bit_positions_high(_filter)` | Get type IDs from bits 64-127 |
| `translate_get_account_history_filter(_low, _high)` | Full filter translation |
| `translate_get_ops_in_block_filter(_low, _high, _virtual)` | Filter with virtual flag |

### Bitmask Format

```
filter_low:  bits 0-63   (operation types 0-63)
filter_high: bits 64-127 (operation types 64-127)

Example: To filter for types 0, 1, 5:
filter_low = 0b100011 = 35
filter_high = 0
```

---

## JSON Utils (`json_utils.sql`)

Handle JSON number limitations for large integers.

| Function | Purpose |
|----------|---------|
| `json_stringify_bigint(_value)` | Convert BIGINT to JSON-safe format |
| `numeric_to_bigint(_value)` | Handle two's complement overflow |

### IEEE 754 Safe Integer Range

JavaScript/JSON numbers are IEEE 754 doubles with 53-bit mantissa:
- Max safe integer: `2^53 - 1 = 9007199254740991`
- Values > max are converted to strings in JSON responses

```sql
/*
 * If _value > 9007199254740991, return as string
 * Otherwise return as number
 */
```

---

## Key Patterns

### Validation Chain
```sql
-- Validate input, then use validated value
_validated_limit := hafah_backend.validate_limit(_limit, 100, 1000);
_validated_page := hafah_backend.validate_page(_page);
```

### Error First
```sql
-- Check for errors before expensive operations
IF _account_id IS NULL THEN
  PERFORM hafah_backend.rest_raise_missing_account(_account_name);
END IF;
```

### Late Binding
```sql
-- Resolve account IDs on smallest result set
WITH filtered AS (
  -- Filter operations first
)
SELECT ...
WHERE account_id = hafah_backend.get_account_id(_name)
```

---

## Expansion Rules

When adding a new utility:

1. Add to appropriate file based on function category
2. Follow existing naming conventions (`validate_*`, `rest_raise_*`, etc.)
3. Add function header comment with PURPOSE, PARAMETERS, RETURNS
4. Update this documentation
