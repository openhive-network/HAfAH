"""REST arguments whose value starts with a PostgREST filter operator reach the function verbatim.

In a GET's query string PostgREST takes such a value (`not.existing`, `eq.blocktrades`) for a
filter on the result, so the argument would never reach the function: `not.existing` answers
PGRST100, `eq.blocktrades` drops the argument (PGRST202, or 42703 for an optional one). Each
case sets one text parameter of an endpoint, in its path or its query, to such a value and
requests it through the rewriter; the answer must equal the function's answer to the same
arguments sent to PostgREST in a JSON body.
"""
import json

import pytest
from rest_client import PostgREST, Rewriter

_PREFIXES = ("not.", "eq.", "in.", "like.", "is.", "fts.")
_SUFFIX = "existing"
_V = "{value}"

# The parameters naming an account: the function answers that the account does not exist.
_ACCOUNT_TARGETS = [
    ("/accounts/{value}/operation-types", "get_acc_op_types", {"account-name": _V}),
    ("/accounts/{value}/operations", "get_ops_by_account", {"account-name": _V}),
    ("/accounts/steemit/operations?transacting-account-name={value}", "get_ops_by_account",
     {"account-name": "steemit", "transacting-account-name": _V}),
    ("/blocks/4000000/operations?account-name={value}", "get_ops_by_block_paging", {"block-num": "4000000", "account-name": _V}),
]

# Every other text parameter of the REST endpoints.
_TEXT_TARGETS = [
    ("/operation-types?partial-operation-name={value}", "get_op_types", {"partial-operation-name": _V}),
    ("/transactions/{value}", "get_transaction", {"transaction-id": _V}),
    ("/operations/{value}", "get_operation", {"operation-id": _V}),
    ("/blocks/{value}", "get_block", {"block-num": _V}),
    ("/blocks/{value}/header", "get_block_header", {"block-num": _V}),
    ("/blocks/{value}/operations", "get_ops_by_block_paging", {"block-num": _V}),
    ("/blocks/4000000/operations?operation-types={value}", "get_ops_by_block_paging", {"block-num": "4000000", "operation-types": _V}),
    ("/blocks?from-block={value}&to-block=4000001", "get_block_range", {"from-block": _V, "to-block": "4000001"}),
    ("/blocks?from-block=4000000&to-block={value}", "get_block_range", {"from-block": "4000000", "to-block": _V}),
    ("/accounts/steemit/operations?operation-types={value}", "get_ops_by_account", {"account-name": "steemit", "operation-types": _V}),
    ("/accounts/steemit/operations?from-block={value}", "get_ops_by_account", {"account-name": "steemit", "from-block": _V}),
    ("/accounts/steemit/operations?to-block={value}", "get_ops_by_account", {"account-name": "steemit", "to-block": _V}),
    ("/operations?from-block={value}&to-block=4000001", "get_operations", {"from-block": _V, "to-block": "4000001"}),
    ("/operations?from-block=4000000&to-block={value}", "get_operations", {"from-block": "4000000", "to-block": _V}),
    ("/operations?from-block=4000000&to-block=4000001&operation-types={value}", "get_operations",
     {"from-block": "4000000", "to-block": "4000001", "operation-types": _V}),
    ("/operations?from-block=4000000&to-block=4000001&operation-begin={value}", "get_operations",
     {"from-block": "4000000", "to-block": "4000001", "operation-begin": _V}),
    ("/market-history/trade-history?from-block={value}&to-block=4000001&result-limit=10", "get_trade_history",
     {"from-block": _V, "to-block": "4000001", "result-limit": "10"}),
    ("/market-history/trade-history?from-block=4000000&to-block={value}&result-limit=10", "get_trade_history",
     {"from-block": "4000000", "to-block": _V, "result-limit": "10"}),
]


def _with(args: dict[str, str], value: str) -> dict[str, str]:
    return {name: value if arg == _V else arg for name, arg in args.items()}


def _error_code(body: object) -> str:
    return str(body.get("code")) if isinstance(body, dict) else ""


@pytest.mark.parametrize("prefix", _PREFIXES)
@pytest.mark.parametrize(("target", "function", "args"), _ACCOUNT_TARGETS + _TEXT_TARGETS,
                         ids=[target for target, _, _ in _ACCOUNT_TARGETS + _TEXT_TARGETS])
def test_operator_prefixed_value_reaches_the_function(rewriter: Rewriter, postgrest: PostgREST, target: str, function: str,
                                                     args: dict[str, str], prefix: str) -> None:
    value = prefix + _SUFFIX
    routed = rewriter.get(target.format(value=value))
    assert not _error_code(routed.body).startswith("PGRST"), routed
    assert routed == postgrest.call(function, _with(args, value))


@pytest.mark.parametrize("prefix", _PREFIXES)
@pytest.mark.parametrize("target", [target for target, _, _ in _ACCOUNT_TARGETS])
def test_operator_prefixed_account_is_named_verbatim(rewriter: Rewriter, target: str, prefix: str) -> None:
    value = prefix + _SUFFIX
    answer = rewriter.get(target.format(value=value))
    assert answer.status == 400, answer
    assert answer.body["message"] == f"Account '{value}' does not exist"


@pytest.mark.parametrize("prefix", _PREFIXES)
def test_operator_prefixed_partial_operation_name_matches_nothing(rewriter: Rewriter, prefix: str) -> None:
    answer = rewriter.get(f"/operation-types?partial-operation-name={prefix}{_SUFFIX}")
    assert (answer.status, answer.body) == (200, [])


@pytest.mark.parametrize(("target", "status"), [
    ("/accounts/not.existing/operation-types", 400),
    ("/accounts/steemit/operation-types", 200),
    # PGRST100 is a 400 too, like the function's answer for an unknown account, and a HEAD
    # answers no body to tell them apart: here the function answers 200 (no operation type).
    ("/operation-types?partial-operation-name=not.existing", 200),
])
def test_head_answers_as_get(rewriter: Rewriter, target: str, status: int) -> None:
    head = rewriter.head(target)
    assert head == rewriter.head(target, method="GET")
    assert head.status == status, head


@pytest.mark.parametrize(("target", "status"), [
    ("/accounts/blocktrades/operation-types", 200),
    ("/accounts/not.existing/operation-types", 400),
])
def test_head_leaves_the_connection_to_the_next_answer(rewriter: Rewriter, target: str, status: int) -> None:
    # A body sent after a HEAD's headers would stay on the connection and be read as the
    # start of the GET's answer, which then fails to parse.
    head, get = rewriter.in_turn(("HEAD", target), ("GET", target))
    assert (head.status, head.body) == (get.status, b""), head
    assert head.headers.get("Content-Type") == get.headers.get("Content-Type")
    assert get.status == status, get
    body = json.loads(get.body)
    assert not _error_code(body).startswith("PGRST"), body
    assert body == rewriter.get(target).body


def test_plain_account_is_answered_as_before(rewriter: Rewriter, postgrest: PostgREST) -> None:
    routed = rewriter.get("/accounts/steemit/operation-types")
    assert routed.status == 200 and 0 in routed.body, routed
    assert routed == postgrest.call("get_acc_op_types", {"account-name": "steemit"})
