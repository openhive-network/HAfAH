# HAfAH under AIDEV

AIDEV verifies changes to this repository through the slots in `project.yaml`,
integrates them into `aidev/integration`, and people merge that into `develop`
through merge requests (as in hive/denser and hive/haf_api_node). GitLab CI doesn't
run for AIDEV branches (`ai/*`, `session/*`, pushes to `aidev/integration`); see
`.gitlab-ci.yml` `workflow:`.

## Suites

`.aidev/run-checks.sh <suite> <step>...` runs the named steps and writes
`test-results/<suite>/junit.xml`, one test case per step, with the step's log tail as
the failure body. `api-smoke` also writes one case per call (`api-smoke.xml`).

| Step | What |
|---|---|
| `shellcheck` | ShellCheck on `scripts/` and `docker/` at **error** severity (they carry warnings today), and on `.aidev/`'s own scripts at the default severity |
| `sql-registered` | every `.sql` file under `db/`, `backend/` and `endpoints/` is applied by `scripts/install_app.sh` |
| `install` | `scripts/install_app.sh` into the stack's HAF database as `haf_admin`, then `hafah_backend.is_setup_completed()` and the SQL checks `.aidev/*_check.sql` (each fabricates the rows it needs and rolls them back) |
| `reinstall` | `scripts/uninstall_app.sh`, then `install` again |
| `api-smoke` | `.aidev/hafah_smoke.py`: PostgREST over the installed schema (as `run_hafah_postgrest.sh` starts it), then JSON-RPC calls (`account_history_api`, `condenser_api`, `block_api`, an unknown method) and REST calls (`/rpc/get_version`, `get_head_block_num`, `get_op_types`, `get_operations`, `get_recent_trades`, `get_block_range`, `get_ops_by_account` with and without an `operation-types` filter and a block range), each checked against the shape an empty chain answers with |

The install steps copy `db/ backend/ endpoints/ scripts/` to a scratch directory and
write `scripts/set_version_in_sql.pgsql` there (`git rev-parse HEAD`, or `aidev` when the
checkout has no usable git), because a workflow checkout may have no `.git`.

| Slot | Steps | HAF stack |
|---|---|---|
| quick, coverage | shellcheck, sql-registered | no |
| full, canary | those plus install, reinstall, api-smoke | yes |
| baseline | install, reinstall, api-smoke | yes |

`static` and `system` are unbound: AIDEV runs neither for a project.

Not covered yet: CI's pytest functional tests (`hafah_pytest_fuctional_tests_*`: a
testnet with hived and test-tools), the tavern pattern tests (a HAF replayed to 5M
blocks), the comparison tests against hived and the JMeter benchmarks. They stay in
GitLab CI.

## The HAF test stack (`test-stack.compose.yml`)

One service, `haf`: the HAF testnet image CI's `find_haf_testnet_image` resolves (HAF
commit `8de693b2`, for `UPSTREAM_BRANCH` `1.28.8-rc3`), started empty with the
`sleep_infinity` maintenance script as CI's `.haf-instance-testnet` service runs it. The
checks reach it as `haf` on the stack's network. When `.gitlab-ci.yml`'s
`UPSTREAM_BRANCH` moves, re-pin the image digest there to
`registry.gitlab.syncad.com/hive/haf/testnet:<new HAF commit, 8 chars>`.

To run the stack checks by hand:

```bash
docker compose -p hafah-checks -f .aidev/test-stack.compose.yml up -d --wait
docker run --rm --user "$(id -u):$(id -g)" --network hafah-checks_default -v "$PWD:/w" -w /w \
    "$(grep -o 'registry[^"]*aidev-tests@sha256:[0-9a-f]*' .aidev/project.yaml)" \
    .aidev/run-checks.sh full shellcheck sql-registered install reinstall api-smoke
docker compose -p hafah-checks -f .aidev/test-stack.compose.yml down -v
```

## The test runtime image (`runtime/`)

The checks run in a container with your uid: `psql:14-1` (the base of this project's
own `Dockerfile`), the `postgrest` binary of `postgrest:v12.0.2`, and `python3` +
`shellcheck` from Alpine's repository, all bases pinned by digest.

When `runtime/Dockerfile` changes (e.g. to follow a new PostgREST in `Dockerfile`),
rebuild and re-pin **in the same commit**:

```bash
.aidev/runtime/build.sh --push   # registry digest if aidev-<input hash> exists, else build + push
# put the printed repo@sha256:<digest> into project.yaml environment.image
```

To build through a pull-through registry cache near the build host, set
`AIDEV_IMAGE_CACHE_BY_REGION` to `region=host:port` pairs, e.g.
`eu=cache.example.org:5001,*=cache2.example.org:5001`: a pair applies when its region is
a label of the host's FQDN, and `*` applies to any other host. Unset, the image is built
straight from `registry.gitlab.syncad.com`.
