"""PostgREST's reserved query parameters keep their PostgREST meaning through the rewriter.

The rewriter forwards a GET of a function as a form-encoded POST, whose fields PostgREST takes
as arguments. `limit`, `offset`, `order`, `select` and the logical filters `and`, `or`,
`not.or` stay in the query string, by their decoded name and by its last dot-separated part,
where they shape the rows the function returns, while the other parameters still reach the
function. Had one reached it as an argument, PostgREST would find no function taking it
(PGRST202).
"""
from typing import Any

import pytest
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


def test_encoded_limit_is_still_limit(rewriter: Rewriter, postgrest: PostgREST) -> None:
    # `%6C` is `l`: the rewriter has to decode a name before it tells a reserved one.
    answer = rewriter.get("/operation-types?%6Cimit=2")
    assert (answer.status, answer.body) == (200, _all_op_types(postgrest)[:2])


def test_dotted_limit_stays_a_postgrest_parameter(rewriter: Rewriter, postgrest: PostgREST) -> None:
    # The limit of an embedded resource, which get_op_types's rows have none of.
    answer = rewriter.get("/operation-types?child.limit=1")
    assert answer == postgrest.get("get_op_types", "child.limit=1")
    assert (answer.status, answer.body["code"]) == (400, "PGRST108"), answer


@pytest.mark.parametrize(("query", "op_type_ids"), [
    ("or=(op_type_id.eq.0,op_type_id.eq.2)", [0, 2]),
    ("and=(op_type_id.gte.1,op_type_id.lte.2)", [1, 2]),
    ("not.or=(op_type_id.gt.1,op_type_id.lt.0)", [0, 1]),
])
def test_logical_filter_filters_the_rows(rewriter: Rewriter, postgrest: PostgREST, query: str,
                                         op_type_ids: list[int]) -> None:
    answer = rewriter.get(f"/operation-types?{query}")
    expected = [row for row in _all_op_types(postgrest) if row["op_type_id"] in op_type_ids]
    assert [row["op_type_id"] for row in expected] == op_type_ids
    assert (answer.status, answer.body) == (200, expected)


def test_logical_filter_beside_an_argument(rewriter: Rewriter, postgrest: PostgREST) -> None:
    answer = rewriter.get("/operation-types?partial-operation-name=vote&or=(op_type_id.eq.0,op_type_id.eq.2)")
    vote_types = _all_op_types(postgrest, **{"partial-operation-name": "vote"})
    assert (answer.status, answer.body) == (200, [row for row in vote_types if row["op_type_id"] in (0, 2)])
    assert [row["operation_name"] for row in answer.body] == ["vote_operation"]


def test_column_filter_beside_an_argument(rewriter: Rewriter, postgrest: PostgREST) -> None:
    answer = rewriter.get("/operation-types?partial-operation-name=vote&op_type_id=eq.0")
    vote_types = _all_op_types(postgrest, **{"partial-operation-name": "vote"})
    assert (answer.status, answer.body) == (200, [row for row in vote_types if row["op_type_id"] == 0])
    assert [row["operation_name"] for row in answer.body] == ["vote_operation"]


def _blocks(postgrest: PostgREST) -> list[Any]:
    answer = postgrest.call("get_block_range", {"from-block": "4000000", "to-block": "4000005"})
    assert answer.status == 200 and len(answer.body) == 6, answer
    rows: list[Any] = answer.body
    return rows


def test_offset_and_limit_trim_the_blocks(rewriter: Rewriter, postgrest: PostgREST) -> None:
    answer = rewriter.get("/blocks?from-block=4000000&to-block=4000005&offset=1&limit=2")
    assert (answer.status, answer.body) == (200, _blocks(postgrest)[1:3])


def test_column_filter_trims_the_blocks(rewriter: Rewriter, postgrest: PostgREST) -> None:
    third = _blocks(postgrest)[2]
    answer = rewriter.get(f"/blocks?from-block=4000000&to-block=4000005&block_id=eq.{third['block_id']}")
    assert (answer.status, answer.body) == (200, [third])
