import pytest

import test_tools as tt

from hafah_local_tools import send_request_to_hafah


def test_get_empty_history(postgrest_hafah, wallet):
    wallet.create_account("alice")
    response = send_request_to_hafah(
        postgrest_hafah, "get_account_history", account="alice", include_reversible=False
    )
    assert len(response["history"]) == 0


@pytest.mark.parametrize(
    "include_reversible",
    (
        True,
        False,
    ),
)
def test_check_for_newly_created_history_operations(
    postgrest_hafah, wallet, node_set, include_reversible
):
    init_node, haf_node = node_set
    wallet.create_account(f"bob-{int(include_reversible)}", hives=100)

    if not include_reversible:
        haf_node.wait_for_irreversible_block()

    response = send_request_to_hafah(
        postgrest_hafah,
        "get_account_history",
        account=f"bob-{int(include_reversible)}",
        include_reversible=include_reversible,
    )

    assert len(response["history"]) > 0


def test_filter_only_transfer_ops(postgrest_hafah, wallet):
    wallet.create_account("carol", hives=100)

    response = send_request_to_hafah(
        postgrest_hafah,
        "get_account_history",
        account="carol",
        include_reversible=True,
        operation_filter_low=4,
    )

    assert len(response["history"]) == 1


@pytest.mark.parametrize("step", (1, 2, 4, 8, 16, 32, 64))
def test_pagination(postgrest_hafah, wallet, step: int):
    amount_of_transfers = 59
    amount_of_operations_from_account_creation = 5
    total_amount_of_operations = (
        amount_of_transfers + amount_of_operations_from_account_creation
    )

    wallet.create_account(f"dan-{step}", hives=100, vests=100)

    with wallet.in_single_transaction():
        for x in range(amount_of_transfers):
            wallet.api.transfer(f"dan-{step}", "null", tt.Asset.Test(1), f"transfer-{x}")
    response = send_request_to_hafah(
        postgrest_hafah, "get_account_history", account=f"dan-{step}", include_reversible=True
    )
    assert len(response["history"]) == total_amount_of_operations

    ops_from_pagination = []
    for start in range(step - 1, total_amount_of_operations, step):
        output = send_request_to_hafah(
            postgrest_hafah,
            "get_account_history",
            account=f"dan-{step}",
            include_reversible=True,
            limit=step,
            start=start,
        )
        assert (
            len(output["history"]) > 0 or start == 0
        ), f"history was empty for start={start}"
        ops_from_pagination += output["history"]
        tt.logger.info(
            f"for start={start}, history has length of {len(output['history'])}"
        )

    ops_from_pagination = list(sorted(ops_from_pagination, key=lambda x: x[0]))
    assert ops_from_pagination == response["history"]
