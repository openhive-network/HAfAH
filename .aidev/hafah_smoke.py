#!/usr/bin/env python3
"""Serve the installed HAfAH schema with PostgREST and check its API answers.

    hafah_smoke.py OUT_DIR

Starts `postgrest` the way scripts/run_hafah_postgrest.sh does (schema
hafah_endpoints, anonymous role hafah_user, root spec `home` — the JSON-RPC
dispatcher) on a free loopback port, against HAFAH_TEST_USER_URL, then makes
the calls in CHECKS. The database is an empty HAF testnet one, so every check
asserts the shape an empty chain answers with, not chain data.

Writes OUT_DIR/api-smoke.xml (one junit case per call) and exits non-zero when
any call fails. To check another method or endpoint, add it to CHECKS.
"""
import json
import os
import socket
import subprocess
import sys
import time
import urllib.error
import urllib.request

HERE = os.path.dirname(os.path.abspath(__file__))
STARTUP_TIMEOUT_S = 60


def rpc(method, params):
    return ("POST", "/", {"jsonrpc": "2.0", "method": method, "params": params, "id": 1})


def result_has(*keys):
    def check(status, body):
        assert status == 200, f"HTTP {status}"
        assert "error" not in body, f"error: {body.get('error')}"
        missing = [k for k in keys if k not in body["result"]]
        assert not missing, f"result lacks {missing}: {body['result']}"
    return check


def result_is(expected):
    def check(status, body):
        assert status == 200, f"HTTP {status}"
        assert body.get("result") == expected, f"result {body.get('result')!r}, expected {expected!r}"
    return check


def rpc_error(code):
    def check(status, body):
        assert status == 200, f"HTTP {status}"
        assert body.get("error", {}).get("code") == code, f"expected error {code}, got {body}"
    return check


def http_ok(status, body):
    assert status == 200, f"HTTP {status}"


def http_error(code, message_part):
    def check(status, body):
        assert status == code, f"HTTP {status}, expected {code}"
        message = (body or {}).get("message", "") if isinstance(body, dict) else ""
        assert message_part in message, f"expected a message containing {message_part!r}, got {body!r}"
    return check


def http_json(kind):
    def check(status, body):
        assert status == 200, f"HTTP {status}"
        assert isinstance(body, kind), f"expected {kind.__name__}, got {body!r}"
    return check


# The Denser wallet's operation-types filter, which takes account_history_by_operations.
WALLET_OPS = "2,3,4,55,54,32,33,27,34,31,28,29,50,57,39,51,49,8"
UNKNOWN_ACCOUNT = http_error(400, "Account 'initminer' does not exist")

# name, request, check(status, decoded body)
CHECKS = [
    ("jsonrpc/account_history_api.get_ops_in_block", rpc("account_history_api.get_ops_in_block", {"block_num": 1}), result_has("ops")),
    ("jsonrpc/account_history_api.enum_virtual_ops", rpc("account_history_api.enum_virtual_ops", {"block_range_begin": 1, "block_range_end": 10}),
     result_has("ops", "ops_by_block", "next_block_range_begin", "next_operation_begin")),
    ("jsonrpc/account_history_api.get_account_history", rpc("account_history_api.get_account_history", {"account": "initminer", "start": -1, "limit": 10}),
     result_has("history")),
    ("jsonrpc/account_history_api.get_transaction.unknown", rpc("account_history_api.get_transaction", {"id": "0" * 40}), rpc_error(-32003)),
    ("jsonrpc/condenser_api.get_ops_in_block", rpc("condenser_api.get_ops_in_block", [1, False]), result_is([])),
    ("jsonrpc/condenser_api.get_account_history", rpc("condenser_api.get_account_history", ["initminer", -1, 10]), result_is([])),
    ("jsonrpc/block_api.get_block", rpc("block_api.get_block", {"block_num": 1}), result_is({})),
    ("jsonrpc/block_api.get_block_header", rpc("block_api.get_block_header", {"block_num": 1}), result_is({})),
    ("jsonrpc/block_api.get_block_range", rpc("block_api.get_block_range", {"starting_block_num": 1, "count": 5}), result_has("blocks")),
    ("jsonrpc/unknown_method", rpc("account_history_api.no_such_method", {}), rpc_error(-32601)),
    ("rest/get_version", ("GET", "/rpc/get_version", None), http_json(dict)),
    ("rest/get_head_block_num", ("GET", "/rpc/get_head_block_num", None), http_ok),
    ("rest/get_op_types", ("GET", "/rpc/get_op_types", None), http_json(list)),
    ("rest/get_operations", ("GET", "/rpc/get_operations?from-block=1&to-block=10", None), http_json(dict)),
    ("rest/get_recent_trades", ("GET", "/rpc/get_recent_trades?result-limit=10", None), http_json(list)),
    ("rest/get_block_range", ("GET", "/rpc/get_block_range?from-block=1&to-block=5", None), http_json(list)),
    # The filtered requests answer exactly as their unfiltered twins on the empty chain.
    ("rest/get_ops_by_account", ("GET", "/rpc/get_ops_by_account?account-name=initminer", None), UNKNOWN_ACCOUNT),
    ("rest/get_ops_by_account.by_operations", ("GET", f"/rpc/get_ops_by_account?account-name=initminer&operation-types={WALLET_OPS}", None),
     UNKNOWN_ACCOUNT),
    ("rest/get_ops_by_account.block_range", ("GET", "/rpc/get_ops_by_account?account-name=initminer&from-block=1&to-block=10", None),
     UNKNOWN_ACCOUNT),
    ("rest/get_ops_by_account.by_operations.block_range",
     ("GET", f"/rpc/get_ops_by_account?account-name=initminer&operation-types={WALLET_OPS}&from-block=1&to-block=10", None),
     UNKNOWN_ACCOUNT),
]


def free_port():
    with socket.socket() as sock:
        sock.bind(("127.0.0.1", 0))
        return sock.getsockname()[1]


def call(base, request):
    method, path, payload = request
    data = None if payload is None else json.dumps(payload).encode()
    req = urllib.request.Request(base + path, data=data, method=method, headers={"Content-Type": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            status, raw = resp.status, resp.read()
    except urllib.error.HTTPError as err:
        status, raw = err.code, err.read()
    text = raw.decode("utf-8", "replace")
    try:
        return status, json.loads(text) if text.strip() else None, text
    except ValueError:
        return status, None, text


def wait_until_serving(base, proc, log_path):
    deadline = time.monotonic() + STARTUP_TIMEOUT_S
    while time.monotonic() < deadline:
        if proc.poll() is not None:
            raise RuntimeError(f"postgrest exited with {proc.returncode}; see {log_path}")
        try:
            if call(base, ("GET", "/rpc/get_version", None))[0] == 200:
                return
        except OSError:
            pass
        time.sleep(1)
    raise RuntimeError(f"postgrest not serving after {STARTUP_TIMEOUT_S}s; see {log_path}")


def main(out):
    os.makedirs(out, exist_ok=True)
    port = free_port()
    base = f"http://127.0.0.1:{port}"
    log_path = os.path.join(out, "postgrest.log")
    env = dict(os.environ,
               PGRST_DB_URI=os.environ["HAFAH_TEST_USER_URL"],
               PGRST_DB_SCHEMA="hafah_endpoints",
               PGRST_DB_ANON_ROLE="hafah_user",
               PGRST_DB_ROOT_SPEC="home",
               PGRST_SERVER_HOST="127.0.0.1",
               PGRST_SERVER_PORT=str(port))
    cases = os.path.join(out, "api-smoke.tsv")
    failed = 0
    with open(log_path, "w") as log, open(cases, "w") as tsv:
        proc = subprocess.Popen(["postgrest"], env=env, stdout=log, stderr=subprocess.STDOUT)
        try:
            wait_until_serving(base, proc, log_path)
            for name, request, check in CHECKS:
                t0 = time.monotonic()
                status, body, text = call(base, request)
                try:
                    check(status, body)
                    verdict, message = "pass", ""
                    print(f"ok   {name}")
                except AssertionError as err:
                    failed += 1
                    verdict, message = "fail", str(err).replace("\t", " ").replace("\n", " ")[:300]
                    print(f"FAIL {name}: {message}\n     response: {text[:500]}")
                tsv.write(f"case\t{name}\t{verdict}\t{time.monotonic() - t0:.3f}\t{message}\n")
        finally:
            proc.terminate()
            try:
                proc.wait(timeout=10)
            except subprocess.TimeoutExpired:
                proc.kill()
    subprocess.run([sys.executable, os.path.join(HERE, "junit_cases.py"), os.path.join(out, "api-smoke.xml"), "api-smoke", cases], check=True)
    print(f"{len(CHECKS) - failed}/{len(CHECKS)} calls answered as expected")
    return 1 if failed else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} OUT_DIR")
    sys.exit(main(sys.argv[1]))
