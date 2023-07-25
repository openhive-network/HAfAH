import pytest
import test_tools as tt

from hafah_local_tools import send_request_to_hafah

def test_get_transaction(postgrest_hafah, node_set):
    init_node, haf_node = node_set

#...--test_get_transaction_in_reversible_block--...
    wallet = tt.Wallet(attach_to=init_node, additional_arguments=["--transaction-serialization=hf26"])
    transaction = wallet.create_account("alice")
    # delete one additional key to compare transactions
    del transaction["rc_cost"]

    for include_reversible in [True, False]:
        tt.logger.info(f"...--test_get_transaction_in_reversible_block_{include_reversible}--...")
        if not include_reversible:
            haf_node.wait_for_irreversible_block()
        response = send_request_to_hafah(
            postgrest_hafah,
            "get_transaction",
            id=transaction["transaction_id"],
            include_reversible=include_reversible,
        )
        assert response == transaction

#...--test_wrong_transaction_id--...
    tt.logger.info(f"...--test_wrong_transaction_id--...")

    for incorrect_id in ["123", "1000000000000000000000000000000000000000", "10000000000000000000000000000000000000001"]:
        for include_reversible in [False, True]:
            with pytest.raises(tt.exceptions.CommunicationError):
                send_request_to_hafah(
                    postgrest_hafah,
                    "get_transaction",
                    id=incorrect_id,
                    include_reversible=include_reversible,
                )

