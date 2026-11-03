"""The rewriter's encoded `path-filter` reaches get_ops_by_block_paging in the forwarded form body."""
import base64

from rest_client import PostgREST, Rewriter


def test_path_filter_selects_the_matching_operations(rewriter: Rewriter, postgrest: PostgREST) -> None:
    path_filter = "value.voter=murh"
    routed = rewriter.get("/blocks/4000000/operations?path-filter=value.voter%3Dmurh")
    assert routed.status == 200, routed
    # Block 4000000 holds murh's vote and its effective_comment_vote.
    assert (routed.body["total_operations"], [op["op"]["value"]["voter"] for op in routed.body["operations_result"]]) == (2, ["murh", "murh"])
    direct = postgrest.call("get_ops_by_block_paging", {"block-num": "4000000", "path-filter": [base64.b64encode(path_filter.encode()).decode()]})
    assert routed == direct
