import pytest

import test_tools as tt

from hafah_local_tools import send_request_to_hafah


@pytest.mark.get_account_history_and_get_transaction
def test_get_empty_history(node_set, wallet):
    init_node, haf_node, postgrest_hafah = node_set
    wallet.create_account("alice")
    response = send_request_to_hafah(
        postgrest_hafah, "get_account_history", account="alice", include_reversible=False
    )
    assert len(response["history"]) == 0


@pytest.mark.get_account_history_and_get_transaction
@pytest.mark.parametrize(
    "include_reversible",
    (
        True,
        False,
    ),
)
def test_check_for_newly_created_history_operations(
    node_set, wallet, include_reversible
):
    init_node, haf_node, postgrest_hafah = node_set
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


@pytest.mark.get_account_history_and_get_transaction
def test_filter_only_transfer_ops(node_set, wallet):
    init_node, haf_node, postgrest_hafah = node_set
    wallet.create_account("carol", hives=100)

    response = send_request_to_hafah(
        postgrest_hafah,
        "get_account_history",
        account="carol",
        include_reversible=True,
        operation_filter_low=4,
    )

    assert len(response["history"]) == 1


@pytest.mark.get_account_history_and_get_transaction
@pytest.mark.parametrize("step", (1, 2, 4, 8, 16, 32, 64))
def test_pagination(node_set, wallet, step: int):
    init_node, haf_node, postgrest_hafah = node_set
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


@pytest.mark.get_account_history_and_get_transaction
@pytest.mark.parametrize(
    "include_reversible",
    (
        True,
        False,
    ),
)
def test_get_transaction_in_reversible_block(
    node_set, wallet, include_reversible
):
    init_node, haf_node, postgrest_hafah = node_set
    wallet.close()
    wallet = tt.Wallet(
        attach_to=init_node, additional_arguments=["--transaction-serialization=hf26"]
    )
    transaction = wallet.create_account(f"ewa-{int(include_reversible)}")
    if not include_reversible:
        haf_node.wait_for_irreversible_block()
    # delete one additional key to compare transactions
    del transaction["rc_cost"]
    response = send_request_to_hafah(
        postgrest_hafah,
        "get_transaction",
        id=transaction["transaction_id"],
        include_reversible=include_reversible,
    )
    assert response == transaction


@pytest.mark.get_account_history_and_get_transaction
@pytest.mark.parametrize(
    "incorrect_id",
    (
        # too short hex, correct hex but unknown transaction, too long hex
        "123",
        "1000000000000000000000000000000000000000",
        "10000000000000000000000000000000000000001",
    ),
)
@pytest.mark.parametrize(
    "include_reversible",
    (
        False,
        True,
    ),
)
def test_wrong_transaction_id(node_set, incorrect_id, include_reversible):
    init_node, haf_node, postgrest_hafah = node_set
    with pytest.raises(tt.exceptions.CommunicationError):
        send_request_to_hafah(
            postgrest_hafah,
            "get_transaction",
            id=incorrect_id,
            include_reversible=include_reversible,
        )
