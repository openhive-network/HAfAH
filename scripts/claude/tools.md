# Tools and Debugging

## Overview

Scripts and commands for managing HAfAH installation, Docker operations, and debugging.

---

## Installation Scripts

### Install Application

```bash
# Host installation
scripts/install_app.sh --postgres-url=postgresql://haf_admin@localhost:5432/haf_block_log

# Docker installation
docker run --rm -it registry.gitlab.syncad.com/hive/hafah:TAG \
  install_app --postgres-url=postgresql://haf_admin@172.17.0.1:5432/haf_block_log
```

### Uninstall Application

```bash
# Host uninstallation
scripts/uninstall_app.sh --postgres-url=postgresql://haf_admin@localhost:5432/haf_block_log

# Docker uninstallation
docker run --rm -it registry.gitlab.syncad.com/hive/hafah:TAG \
  uninstall_app --postgres-url=postgresql://haf_admin@172.17.0.1:5432/haf_block_log
```

---

## Docker Commands

### Build Image

```bash
scripts/ci-helpers/build_instance.sh "postgrest-latest" . registry.gitlab.syncad.com/hive/hafah \
  --http-port=80 \
  --haf-postgres-url=postgresql://haf_admin@haf-instance:5432/haf_block_log
```

### Run PostgREST Server

```bash
docker run --rm -it -p 8081:6543 \
  -e POSTGRES_URL=postgresql://hafah_user@172.17.0.1:5432/haf_block_log \
  registry.gitlab.syncad.com/hive/hafah:TAG
```

**Note:** Internal port `6543` is fixed. External port (8081) is configurable.

---

## Common Debugging

### Check Installation Status

```sql
SELECT hafah_backend.is_setup_completed();
```

### Check Version

```sql
SELECT * FROM hafah_backend.version;
```

Or via API:
```bash
curl http://localhost:3000/version
```

### Check Head Block

```bash
curl http://localhost:3000/head-block
```

### Test JSON-RPC

```bash
curl -X POST http://localhost:3000/ \
  -H 'Content-Type: application/json' \
  -d '{
    "jsonrpc": "2.0",
    "method": "account_history_api.get_account_history",
    "params": {"account": "blocktrades", "start": -1, "limit": 10},
    "id": 0
  }'
```

### Test REST Endpoint

```bash
curl "http://localhost:3000/accounts/blocktrades/operations?page-size=10"
```

---

## CI Troubleshooting

### Common Pipeline Failures

| Issue | Cause | Fix |
|-------|-------|-----|
| HAF data missing | Cache expired | Re-run with fresh cache |
| Connection refused | PostgREST not ready | Increase startup delay |
| Test timeout | Slow queries | Check query plans |
| Image not found | Build failed | Check build logs |

### Check HAF Cache

```bash
# Available caches on CI server
ssh hive-builder-10 'ls -lt /nfs/ci-cache/haf/*.tar | head -5'
```

### Quick Test Mode

Skip HAF data preparation:
```yaml
variables:
  QUICK_TEST: "true"
  QUICK_TEST_HAF_COMMIT: "<sha>"
```

---

## Database Debugging

### Check Query Plan

```sql
EXPLAIN ANALYZE
SELECT * FROM hafah_endpoints.get_ops_by_account('blocktrades', NULL, 1, 100, NULL, NULL, NULL, NULL);
```

### Check Function Calls

```sql
-- Enable function logging
SET log_statement = 'all';
SET log_min_duration_statement = 0;
```

### Check Roles

```sql
SELECT rolname, rolsuper, rolinherit FROM pg_roles
WHERE rolname IN ('haf_admin', 'hafah_owner', 'hafah_user');
```

### Check Schema Permissions

```sql
SELECT nspname, rolname,
  has_schema_privilege(rolname, nspname, 'USAGE') as usage,
  has_schema_privilege(rolname, nspname, 'CREATE') as create
FROM pg_namespace, pg_roles
WHERE nspname IN ('hafah_backend', 'hafah_endpoints')
  AND rolname IN ('hafah_user', 'hafah_owner');
```

---

## Log Files

| Component | Log Location |
|-----------|--------------|
| PostgREST | stdout (Docker) or journalctl |
| PostgreSQL | `$PGDATA/log/` |
| CI Pipeline | GitLab job output |

---

## Expansion Rules

When adding new tools or scripts:

1. Add documentation to this file
2. Include example commands
3. Document common failure modes
4. Update troubleshooting section if applicable
