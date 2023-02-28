import pytest
import test_tools as tt


def test_default_args_value(postgrest):
    response = postgrest.api.account_history.get_ops_in_block()
    assert len(response['ops']) == 0


@pytest.mark.parametrize('only_virtual, number_of_ops', (
        (False, 3),
        (True, 2)
))
def test_filter_virtual_ops(postgrest, node_with_sql_serializer, only_virtual, number_of_ops):
    wallet = tt.Wallet(attach_to=node_with_sql_serializer)
    block_number = wallet.create_account('alice')['block_num']
    response = postgrest.api.account_history.get_ops_in_block(block_num=block_number,
                                                              only_virtual=only_virtual,
                                                              include_reversible=True)
    assert len(response['ops']) == number_of_ops


@pytest.mark.parametrize('include_reversible, comparison_type', (
        (False, '__eq__'),
        (True, '__gt__')
))
def test_get_operations_in_block_with_and_without_reversible(postgrest,
                                                             node_with_sql_serializer,
                                                             include_reversible,
                                                             comparison_type):
    response = postgrest.api.account_history.get_ops_in_block(block_num=1,
                                                              only_virtual=False,
                                                              include_reversible=include_reversible)
    assert getattr(len(response['ops']), comparison_type)(0)


def test_get_ops_in_non_existent_block(postgrest, node_with_sql_serializer):
    response = postgrest.api.account_history.get_ops_in_block(block_num=-1)
    assert len(response['ops']) == 0
