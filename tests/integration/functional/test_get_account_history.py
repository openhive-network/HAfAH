import pytest

import test_tools as tt


def test_get_empty_history(postgrest, node_with_sql_serializer):
    tt.logger.info(f'Start get empty history')

    # WHEN
    response = postgrest.api.account_history.get_account_history(account='null', include_reversible=False)

    # THEN
    assert len(response['history']) == 0


@pytest.mark.parametrize('include_reversible', (
        True, False,
))
def test_check_for_newly_created_history_operations(postgrest, node_with_sql_serializer, include_reversible):
    tt.logger.info(f'Start checking for newly created history operations')

    # WHEN
    wallet = tt.Wallet(attach_to=node_with_sql_serializer)
    wallet.create_account('alice', hives=100)

    response = postgrest.api.account_history.get_account_history(account='alice',
                                                                 include_reversible=include_reversible,
                                                                 operation_filter_low=512)

    # THEN
    assert len(response['history']) == int(include_reversible)


def test_filter_only_transfer_ops(postgrest, node_with_sql_serializer, db_session):
    tt.logger.info(f'Start filtering only for transfer operations')

    # WHEN
    wallet = tt.Wallet(attach_to=node_with_sql_serializer)
    wallet.create_account('alice', hives=100)

    while db_session.execute("select count(*) from hive.operations_reversible WHERE op_type_id=2").fetchall()[0][0] == 0:
        tt.logger.debug("no reversible operations found, waiting one more block....")
        node_with_sql_serializer.wait_number_of_blocks(1)

    response_with_rev = postgrest.api.account_history.get_account_history(account='alice',
                                                                          include_reversible=True,
                                                                          operation_filter_low=4)

    response_without_rev = postgrest.api.account_history.get_account_history(account='alice',
                                                                             include_reversible=False,
                                                                             operation_filter_low=4)

    # THEN
    assert len(response_with_rev['history']) == 1
    assert len(response_without_rev['history']) == 0


@pytest.mark.parametrize("step", (1, 2, 4, 8, 16, 32, 64))
def test_pagination(postgrest, node_with_sql_serializer, db_session, step: int):
    amount_of_transfers = 59
    amount_of_operations_from_account_creation = 5
    total_amount_of_operations = amount_of_transfers + amount_of_operations_from_account_creation

    wallet = tt.Wallet(attach_to=node_with_sql_serializer)
    wallet.create_account('alice', hives=100, vests=100)

    with wallet.in_single_transaction():
        for x in range(amount_of_transfers):
            wallet.api.transfer('alice', 'null', tt.Asset.Test(1), f"transfer-{x}")
    response = postgrest.api.account_history.get_account_history(account='alice', include_reversible=True)
    assert len(response['history']) == total_amount_of_operations

    ops_from_pagination = []
    for start in range(step - 1, total_amount_of_operations, step):
        output = postgrest.api.account_history.get_account_history(account='alice', include_reversible=True, limit=step,
                                                                   start=start)
        assert len(output['history']) > 0 or start == 0, f"history was empty for start={start}"
        ops_from_pagination += output['history']
        tt.logger.info(f"for start={start}, history has length of {len(output['history'])}")

    ops_from_pagination = list(sorted(ops_from_pagination, key=lambda x: x[0]))
    assert ops_from_pagination == response['history']
