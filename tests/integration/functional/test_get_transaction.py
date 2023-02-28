import pytest
import test_tools as tt

from hafah_local_tools import send_request_to_hafah


@pytest.mark.parametrize(
    "include_reversible",
    (
        True,
        False,
    ),
)
def test_get_transaction_in_reversible_block(
    postgrest_hafah, node_set, include_reversible
):
    init_node, haf_node = node_set
    wallet = tt.Wallet(
        attach_to=init_node, additional_arguments=["--transaction-serialization=hf26"]
    )
    transaction = wallet.create_account("alice")
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
def test_wrong_transaction_id(postgrest_hafah, incorrect_id, include_reversible):
    with pytest.raises(tt.exceptions.CommunicationError):
        send_request_to_hafah(
            postgrest_hafah,
            "get_transaction",
            id=incorrect_id,
            include_reversible=include_reversible,
        )
