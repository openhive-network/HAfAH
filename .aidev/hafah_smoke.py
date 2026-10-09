#!/usr/bin/env python3
"""Serve the installed HAfAH schema with PostgREST and check its API answers.

    hafah_smoke.py OUT_DIR

Starts PostgREST (.aidev/postgrest.py) over the run's clone of the shared HAF,
which holds the chain up to block 5000000, then makes the calls in CHECKS; each
asserts data that chain answers with (steemit's history, block 4000000, ...).

Writes OUT_DIR/api-smoke.xml (one junit case per call) and exits non-zero when
any call fails. To check another method or endpoint, add it to CHECKS.
"""
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request

from postgrest import serving

HERE = os.path.dirname(os.path.abspath(__file__))


def rpc(method, params):
    return ("POST", "/", {"jsonrpc": "2.0", "method": method, "params": params, "id": 1})


def _extracted(extract, value):
    try:
        return extract(value)
    except (KeyError, IndexError, TypeError) as err:
        raise AssertionError(f"answer lacks the checked field ({type(err).__name__}: {err})") from err


def rpc_result(expected, extract):
    """The JSON-RPC result, through extract, equals expected."""
    def check(status, body) -> None:
        assert status == 200, f"HTTP {status}"
        assert "error" not in body, f"error: {body.get('error')}"
        got = _extracted(extract, body["result"])
        assert got == expected, f"got {got!r}, expected {expected!r}"
    return check


def rpc_error(code):
    def check(status, body) -> None:
        assert status == 200, f"HTTP {status}"
        assert body.get("error", {}).get("code") == code, f"expected error {code}, got {body}"
    return check


def http_body(expected, extract):
    """The REST answer is 200 and its body, through extract, equals expected."""
    def check(status, body) -> None:
        assert status == 200, f"HTTP {status}"
        got = _extracted(extract, body)
        assert got == expected, f"got {got!r}, expected {expected!r}"
    return check


def http_error(code, message_part):
    def check(status, body) -> None:
        assert status == code, f"HTTP {status}, expected {code}"
        message = (body or {}).get("message", "") if isinstance(body, dict) else ""
        assert message_part in message, f"expected a message containing {message_part!r}, got {body!r}"
    return check


def ops_count(result):
    return len(result["ops"])


def totals(body):
    return body["total_operations"], body["total_pages"]


# The Denser wallet's operation-types filter, which takes account_history_by_operations.
WALLET_OPS = "2,3,4,55,54,32,33,27,34,31,28,29,50,57,39,51,49,8"
# A transaction of block 4000000 (its first).
KNOWN_TRX = "9e19c9082fea1a87f9dede8c9854a243185402b8"
BLOCK_1_ID = "0000000109833ce528d5bbfb3f6225b39ee10086"

# name, request, check(status, decoded body). Expected values are the chain's to
# block 5000000; steemit's history there is account_op_seq_no 0..4265.
CHECKS = [
    ("jsonrpc/account_history_api.get_ops_in_block", rpc("account_history_api.get_ops_in_block", {"block_num": 4000000}), rpc_result(12, ops_count)),
    ("jsonrpc/account_history_api.get_ops_in_block.only_virtual",
     rpc("account_history_api.get_ops_in_block", {"block_num": 4000000, "only_virtual": True}), rpc_result(5, ops_count)),
    ("jsonrpc/account_history_api.enum_virtual_ops", rpc("account_history_api.enum_virtual_ops", {"block_range_begin": 4000000, "block_range_end": 4000010}),
     rpc_result((43, 4000010), lambda r: (len(r["ops"]), r["next_block_range_begin"]))),
    ("jsonrpc/account_history_api.get_account_history", rpc("account_history_api.get_account_history", {"account": "steemit", "start": -1, "limit": 10}),
     rpc_result([4256, 4265], lambda r: [r["history"][0][0], r["history"][-1][0]])),
    ("jsonrpc/account_history_api.get_transaction", rpc("account_history_api.get_transaction", {"id": KNOWN_TRX}),
     rpc_result((4000000, KNOWN_TRX), lambda r: (r["block_num"], r["transaction_id"]))),
    ("jsonrpc/account_history_api.get_transaction.unknown", rpc("account_history_api.get_transaction", {"id": "0" * 40}), rpc_error(-32003)),
    ("jsonrpc/condenser_api.get_ops_in_block", rpc("condenser_api.get_ops_in_block", [4000000, False]), rpc_result(12, len)),
    ("jsonrpc/condenser_api.get_account_history", rpc("condenser_api.get_account_history", ["steemit", -1, 10]),
     rpc_result((10, 4265), lambda r: (len(r), r[-1][0]))),
    ("jsonrpc/block_api.get_block", rpc("block_api.get_block", {"block_num": 1}),
     rpc_result((BLOCK_1_ID, "initminer"), lambda r: (r["block"]["block_id"], r["block"]["witness"]))),
    ("jsonrpc/block_api.get_block_header", rpc("block_api.get_block_header", {"block_num": 1}),
     rpc_result("2016-03-24T16:05:00", lambda r: r["header"]["timestamp"])),
    ("jsonrpc/block_api.get_block_range", rpc("block_api.get_block_range", {"starting_block_num": 4000000, "count": 5}),
     rpc_result(["003d0900", "003d0901", "003d0902", "003d0903", "003d0904"], lambda r: [b["block_id"][:8] for b in r["blocks"]])),
    ("jsonrpc/unknown_method", rpc("account_history_api.no_such_method", {}), rpc_error(-32601)),
    ("rest/get_version", ("GET", "/rpc/get_version", None), http_body("PostgRESTHAfAH", lambda b: b["app_name"])),
    ("rest/get_head_block_num", ("GET", "/rpc/get_head_block_num", None), http_body(5000000, lambda b: b)),
    ("rest/get_op_types", ("GET", "/rpc/get_op_types", None),
     http_body({"op_type_id": 0, "operation_name": "vote_operation", "is_virtual": False}, lambda b: b[0])),
    ("rest/get_operations", ("GET", "/rpc/get_operations?from-block=4000000&to-block=4000001", None), http_body(17, lambda b: len(b["ops"]))),
    ("rest/get_transaction", ("GET", f"/rpc/get_transaction?transaction-id={KNOWN_TRX}", None), http_body(4000000, lambda b: b["block_num"])),
    ("rest/get_ops_by_block_paging", ("GET", "/rpc/get_ops_by_block_paging?block-num=4000000", None), http_body((12, 1), totals)),
    ("rest/get_recent_trades", ("GET", "/rpc/get_recent_trades?result-limit=10", None), http_body(10, len)),
    ("rest/get_block", ("GET", "/rpc/get_block?block-num=1", None), http_body("initminer", lambda b: b["witness"])),
    ("rest/get_block_range", ("GET", "/rpc/get_block_range?from-block=4000000&to-block=4000004", None), http_body(5, len)),
    ("rest/get_ops_by_account", ("GET", "/rpc/get_ops_by_account?account-name=steemit", None), http_body((4266, 43), totals)),
    ("rest/get_ops_by_account.by_operations", ("GET", f"/rpc/get_ops_by_account?account-name=steemit&operation-types={WALLET_OPS}", None),
     http_body((1235, 13), totals)),
    ("rest/get_ops_by_account.block_range", ("GET", "/rpc/get_ops_by_account?account-name=steemit&from-block=1&to-block=100000", None),
     http_body((1067, 11), totals)),
    ("rest/get_ops_by_account.by_operations.block_range",
     ("GET", f"/rpc/get_ops_by_account?account-name=steemit&operation-types={WALLET_OPS}&from-block=1&to-block=100000", None),
     http_body((7, 1), totals)),
    ("rest/get_ops_by_account.unknown", ("GET", "/rpc/get_ops_by_account?account-name=no-such-acct", None),
     http_error(400, "Account 'no-such-acct' does not exist")),
]


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


def main(out):
    os.makedirs(out, exist_ok=True)
    cases = os.path.join(out, "api-smoke.tsv")
    failed = 0
    with serving(os.path.join(out, "postgrest.log")) as base, open(cases, "w") as tsv:
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
    subprocess.run([sys.executable, os.path.join(HERE, "junit_cases.py"), os.path.join(out, "api-smoke.xml"), "api-smoke", cases], check=True)
    print(f"{len(CHECKS) - failed}/{len(CHECKS)} calls answered as expected")
    return 1 if failed else 0


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} OUT_DIR")
    sys.exit(main(sys.argv[1]))
