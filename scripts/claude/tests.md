# Testing Guide

## Overview

HAfAH uses multiple test types to ensure API correctness and performance.

| Test Type | Framework | Purpose |
|-----------|-----------|---------|
| **Tavern** | pytest + tavern | REST API integration tests |
| **Functional** | pytest | Installation and setup tests |
| **Performance** | JMeter | Load testing and benchmarks |

---

## Quick Reference

```bash
# Tavern tests (REST API)
cd tests/tavern
pytest -n auto --junitxml report.xml .

# Single tavern test
pytest tests/tavern/get_block/positive/first_block.tavern.yaml

# Functional tests
cd tests/integration/functional
pytest --junitxml report.xml \
  --postgrest-hafah-adress=app:6543 \
  --postgres-db-url=postgresql://haf_admin@haf-instance:5432/haf_block_log \
  -m PYTEST_MARK

# Performance tests
./tests/performance_test.py --postgres postgresql:///haf_block_log
```

---

## Test Directory Structure

```
tests/
├── integration/
│   └── functional/          # pytest functional tests
├── tavern/                   # Tavern REST API tests
│   ├── get_block/
│   ├── get_account_history/
│   ├── get_transaction/
│   └── ...
├── performance_data/
│   └── CSV/                  # JMeter input data
└── performance_test.py       # JMeter runner script
```

---

## Tavern Tests

Tavern tests verify REST API responses against expected patterns.

### Structure

Each test is a YAML file with:
- Request definition (method, URL, params)
- Expected response (status, body patterns)

**Example:** `tests/tavern/get_block/positive/first_block.tavern.yaml`

```yaml
test_name: Get first block
stages:
  - name: Request first block
    request:
      url: "{host}/blocks/1"
      method: GET
    response:
      status_code: 200
      json:
        block_num: 1
```

### Running Tavern Tests

```bash
# All tests (parallel)
cd tests/tavern
pytest -n auto .

# Single test file
pytest tests/tavern/get_block/positive/first_block.tavern.yaml

# Tests matching pattern
pytest tests/tavern/get_account_history/ -k "positive"
```

### Test Marks

Tests are marked for CI pipeline organization:
- `enum_virtual_ops_and_get_ops_in_block`
- `get_account_history_and_get_transaction`

---

## Functional Tests

Located in `tests/integration/functional/`.

### Prerequisites

- Running HAF database with HAfAH installed
- PostgREST server running

### Command Line Options

| Option | Description |
|--------|-------------|
| `--postgrest-hafah-adress` | HAfAH PostgREST address |
| `--postgres-db-url` | PostgreSQL connection string |
| `-m MARK` | Run tests with specific mark |

---

## Performance Tests

JMeter-based load testing via `tests/performance_test.py`.

### Setup Requirements

- JMeter installed (`/usr/bin/jmeter` or specify path)
- Java 11+ runtime
- PostgreSQL JDBC driver

### Running Performance Tests

```bash
# Standard test against running instance
./tests/performance_test.py -p 3000 --no-launch

# Direct database test
./tests/performance_test.py --postgres postgresql:///haf_block_log

# Custom workdir and threads
./tests/performance_test.py -d /tmp/workdir -t 32
```

### Input Data Formats

**PERF format** (HTTP and SQL):
```csv
<block_num>;<block_end>;<account>;<tx_hash>
2889001;2889005;frankjones;ef73d8fadf17e2590c6d96efc1ca868edd7dd613
```

**CL format** (constant load, HTTP only):
```csv
<endpoint>|<json_body>
get_account_history|{"jsonrpc": "2.0", ...}
```

### Available Input Files

```bash
# List available test data
./tests/performance_test.py -l
```

Output shows naming convention:
- `perf_` - Performance mode (500 samples)
- `cl_` - Constant load mode (infinite loop)
- `60M` - Requires 60M blocks
- `heavy` - Large response samples
- `light` - Fast response samples

---

## CI Pipeline Integration

Tests run in GitLab CI with these jobs:

| Job | Test Type | Data Source |
|-----|-----------|-------------|
| `tavern-tests` | Tavern | Live HAF database |
| `functional-tests` | pytest | Live HAF database |
| `pattern-tests` | Tavern | Pre-recorded patterns |

### CI Environment

- HAF data cached via NFS (`/nfs/ci-cache/haf/`)
- Docker containers for isolation
- Automatic HAF/Hive image detection

### Quick Test Mode

Skip data preparation in CI:
```bash
# Set in pipeline variables
QUICK_TEST=true
QUICK_TEST_HAF_COMMIT=<sha>
```

Find available caches:
```bash
ssh hive-builder-10 'ls -lt /nfs/ci-cache/haf/*.tar | head -5'
```

---

## Writing New Tests

### Tavern Test Template

```yaml
---
test_name: Descriptive test name

marks:
  - mark_name

stages:
  - name: Stage description
    request:
      url: "{host}/endpoint"
      method: GET
      params:
        param1: value1
    response:
      status_code: 200
      json:
        expected_key: expected_value
```

### Test Organization

| Test Type | Location | Naming |
|-----------|----------|--------|
| Positive | `{endpoint}/positive/` | `descriptive_name.tavern.yaml` |
| Negative | `{endpoint}/negative/` | `error_case.tavern.yaml` |
| Edge cases | `{endpoint}/edge/` | `boundary_test.tavern.yaml` |

---

## Expansion Rules

When adding new tests:

1. Place tavern tests in appropriate `tests/tavern/{endpoint}/` directory
2. Use descriptive names that explain the test scenario
3. Add appropriate pytest marks for CI organization
4. For performance tests, add CSV data to `tests/performance_data/CSV/`
5. Update this documentation
