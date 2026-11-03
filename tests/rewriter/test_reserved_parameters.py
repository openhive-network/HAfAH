"""PostgREST's reserved query parameters keep their PostgREST meaning through the rewriter.

The rewriter forwards a GET of a function as a form-encoded POST, whose fields PostgREST takes
as arguments. `limit`, `offset`, `order` and `select` stay in the query string, where they
shape the rows the function returns, while the other parameters still reach the function.
"""
from typing import Any

from rest_client import PostgREST, Rewriter


def _all_op_types(postgrest: PostgREST, **args: str) -> list[Any]:
    answer = postgrest.call("get_op_types", args)
    assert answer.status == 200 and len(answer.body) >= 3, answer
    rows: list[Any] = answer.body
    return rows


def test_limit_trims_the_rows(rewriter: Rewriter, postgrest: PostgREST) -> None:
    answer = rewriter.get("/operation-types?limit=2")
    assert (answer.status, answer.body) == (200, _all_op_types(postgrest)[:2])


def test_offset_and_limit_select_rows(rewriter: Rewriter, postgrest: PostgREST) -> None:
    answer = rewriter.get("/operation-types?offset=1&limit=2")
    assert (answer.status, answer.body) == (200, _all_op_types(postgrest)[1:3])


def test_select_picks_the_columns(rewriter: Rewriter) -> None:
    answer = rewriter.get("/operation-types?select=operation_name&limit=1")
    assert (answer.status, answer.body) == (200, [{"operation_name": "vote_operation"}])


def test_order_beside_an_argument(rewriter: Rewriter, postgrest: PostgREST) -> None:
    answer = rewriter.get("/operation-types?partial-operation-name=vote&order=op_type_id.desc")
    assert (answer.status, answer.body) == (200, _all_op_types(postgrest, **{"partial-operation-name": "vote"})[::-1])


def test_operator_prefixed_argument_beside_limit(rewriter: Rewriter) -> None:
    answer = rewriter.get("/operation-types?partial-operation-name=not.existing&limit=1")
    assert (answer.status, answer.body) == (200, [])
