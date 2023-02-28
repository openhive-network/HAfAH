import pytest
import test_tools as tt


@pytest.mark.parametrize('include_reversible', (
        True, False,
))
def test_get_transaction_in_reversible_block(postgrest, node_with_sql_serializer, include_reversible):
    wallet = tt.Wallet(attach_to=node_with_sql_serializer, additional_arguments=['--transaction-serialization=hf26'])
    transaction = wallet.create_account('alice')
    if not include_reversible:
        node_with_sql_serializer.wait_for_irreversible_block()
    # delete one additional key to compare transactions
    del transaction['rc_cost']
    response = postgrest.api.account_history.get_transaction(id=transaction['transaction_id'],
                                                             include_reversible=include_reversible)
    assert response == transaction


@pytest.mark.parametrize('incorrect_id', (
        # too short hex, correct hex but unknown transaction, too long hex
        '123', '1000000000000000000000000000000000000000', '10000000000000000000000000000000000000001',
))
@pytest.mark.parametrize('include_reversible', (
        False, True,
))
def test_wrong_transaction_id(postgrest, node_with_sql_serializer, incorrect_id, include_reversible):
    with pytest.raises(tt.exceptions.CommunicationError):
        postgrest.api.account_history.get_transaction(id=incorrect_id, include_reversible=include_reversible)
