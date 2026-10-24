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
| `shellcheck` | ShellCheck at its default severity on `scripts/`, `docker/` and `.aidev/`'s own scripts |
| `sql-registered` | every `.sql` file under `db/`, `backend/` and `endpoints/` is applied by `scripts/install_app.sh` |
| `install` | a per-run copy-on-write clone of the shared HAF (below), `scripts/install_app.sh` into it as `haf_shared_consumer`, then `hafah_backend.is_setup_completed()` and the SQL checks `.aidev/*_check.sql` (read-only checks against the chain data) |
| `reinstall` | the schemas dropped (`scripts/uninstall_app.sh` without its role statements), then `install` again |
| `api-smoke` | `.aidev/hafah_smoke.py`: PostgREST over the installed schema (`.aidev/postgrest.py`, as `run_hafah_postgrest.sh` starts it), then JSON-RPC calls (`account_history_api`, `condenser_api`, `block_api`, an unknown method, an unknown transaction) and REST calls (`get_version`, `get_head_block_num`, `get_op_types`, `get_operations`, `get_transaction`, `get_ops_by_block_paging`, `get_recent_trades`, `get_block`, `get_block_range`, `get_ops_by_account` with and without the Denser wallet's `operation-types` filter and a block range, an unknown account), each checked against the 5M-block chain's answer (e.g. `steemit`: 4266 operations, 1235 with the wallet filter) |
| `tavern` | `.aidev/hafah_tavern.py`: the tavern pattern tests (`tests/tavern`, as CI's `hafah_pytest_rest_api_pattern_tests`) against PostgREST over the clone, 4 xdist workers, run from a copy in `test-results/<suite>/tavern/` (the comparator writes each answer beside its test); `tavern.xml`, one case per test |

The install steps copy `db/ backend/ endpoints/ scripts/` to a scratch directory and
write `scripts/set_version_in_sql.pgsql` there (`git rev-parse HEAD`, or `aidev` when the
checkout has no usable git), because a workflow checkout may have no `.git`.

| Slot | Steps | Shared HAF |
|---|---|---|
| quick, coverage | shellcheck, sql-registered | no |
| full, canary | those plus install, reinstall, api-smoke, tavern | yes |
| baseline | install, reinstall, api-smoke | yes |

`static` and `system` are unbound: AIDEV runs neither for a project.

Not covered yet: CI's pytest functional tests (`hafah_pytest_fuctional_tests_*`: a
testnet with hived and test-tools), the comparison tests against hived and the JMeter
benchmarks. They stay in GitLab CI.

## The db shape (`performance:`)

`full`'s advisory `db_shape` suite plans the `performance.queries` on a captured shape
of steem-18's HAF, once with the base tree's hafah code and once with the candidate's
(aidev's `docs/operations/db-shape.md`). `performance.shape.apply` runs
`.aidev/shape-apply.sh` in each tree to install that code on its shape copy:
`scripts/install_app.sh` itself, from a scratch copy of the sources, with
`.aidev/shape-psql.sh` first on `PATH` as `psql`. Each of the install's psql calls
becomes one run of `$AIDEV_DB_SHAPE_PSQL` with the call's `-c` commands and `-f` files on
stdin, because the shape server has no network and a `-f` path would resolve inside it.
Before the install it drops the `hafah_*` schemas the shape restored as `postgres`'s
and grants the app's roles `CREATE` on the copy.

A query whose function picks a branch at run time (rare/common types or partners)
is declared once per branch. The shape has no rows, so a `nested` call cannot take
production's branch.

## The shared HAF (`sandbox.external`)

The slots without `stack: false` declare `sandbox.external: [{name: haf, provider:
haf/haf}]`: a HAF replayed to block 5000000 that an AIDEV session of the `haf` project
hosts for every HAF app's checks. AIDEV hands the suite its address as
`AIDEV_EXTERNAL_HAF_HOST`/`_PORT` and lets the runtime container reach it and nothing
else; when it is down the slot is refused as environmental, naming the provider.

`run-checks.sh` connects as `haf_shared_consumer` (trusted from the fleet LAN, no
password) and, at the first step that needs it:

1. `select haf_shared.clone_run_database('<run id>')` in database `haf_shared` returns
   `run_<run id>`, a copy-on-write clone (about a second); the run id is
   `hafah-<suite>-<UTC time>-<random>`, so concurrent runs never share a clone;
2. grants `CREATE, CONNECT` on the clone to `hafah_owner` and `hafah_user` (the shared
   HAF creates both roles and makes the consumer a member of `hafah_owner`);
3. installs from the staged copy, whose `db/builtin_roles.sql` is empty (a
   non-superuser cannot run it even when the roles exist) and whose uninstall drops the
   schemas only (`DROP OWNED BY` the app's roles would revoke their grants on every
   other run's clone too, database privileges being cluster-wide);
4. on exit, pass or fail, `haf_shared.drop_run_database('<run id>')`; a clone a killed
   run leaves behind is reaped by the provider.

PostgREST connects to the clone as `haf_shared_consumer` with `PGRST_DB_ANON_ROLE=hafah_user`.

To run the stack checks by hand against the shared HAF (`aidev session status
haf-shared` shows its endpoint):

```bash
docker build -t hafah-aidev-tests .aidev/runtime \
    --build-arg BASE_IMAGE=registry.gitlab.syncad.com/hive/common-ci-configuration/python-test-tools:develop
docker run --rm --user "$(id -u):$(id -g)" -v "$PWD:/w" -w /w \
    -e AIDEV_EXTERNAL_HAF_HOST=<host> -e AIDEV_EXTERNAL_HAF_PORT=<port> hafah-aidev-tests \
    .aidev/run-checks.sh full shellcheck sql-registered install reinstall api-smoke tavern
```

## The test runtime image (`runtime/`)

The checks run in a container with your uid, built from `runtime/Dockerfile` on the
base `project.yaml`'s `environment.base` follows: common-ci-configuration's
`python-test-tools:develop`, the image CI's lint and test jobs use. It brings Python
3.14, `tavern`, `pytest`, `pytest-xdist`, `bash`, `psql`, `shellcheck` and the
`postgrest` binary at the versions in common-ci-configuration's `docker-bake.hcl`; the
Dockerfile adds only hive/tests_api (`validate_response`, the tavern tests' comparator)
at the commit its `TESTS_API_COMMIT` names. Nothing is installed at run time.

No tool version is pinned here. AIDEV resolves the `develop` tag before every run and
rebuilds the image when the tag or the Dockerfile moves, so nothing has to be re-pinned
in this repository; a tool upgrade that breaks a check is fixed when it breaks. The
`environment.image` digest is only the seed AIDEV reads before a slot resolves.
