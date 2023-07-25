import pytest
import test_tools as tt

from hafah_local_tools import send_request_to_hafah

def test_get_ops_in_block(postgrest_hafah, node_set):
    init_node, haf_node = node_set
    wallet = tt.Wallet(attach_to=init_node)

#...--test_default_args_value--...
    tt.logger.info("...--test_default_args_value--...")
    response = send_request_to_hafah(postgrest_hafah, "get_ops_in_block")
    assert len(response["ops"]) == 0

#...--test_filter_virtual_ops--...
    tt.logger.info("...--test_filter_virtual_ops--...")
    block_number = wallet.create_account("alice")["block_num"]
    for only_virtual, number_of_ops in [(False, 3), (True, 2)]:
        response = send_request_to_hafah(
            postgrest_hafah,
            "get_ops_in_block",
            block_num=block_number,
            only_virtual=only_virtual,
            include_reversible=True,
        )
        assert len(response["ops"]) == number_of_ops


#...--test_get_operations_in_block_with_and_without_reversible--...
    tt.logger.info("...--test_get_operations_in_block_with_and_without_reversible--...")
    for include_reversible, comparison_type in [(False, "__eq__"), (True, "__gt__")]:
        response = send_request_to_hafah(
            postgrest_hafah,
            "get_ops_in_block",
            block_num=1,
            only_virtual=False,
            include_reversible=include_reversible,
        )
        assert getattr(len(response["ops"]), comparison_type)(0)


#...--test_get_ops_in_non_existent_block--...
    tt.logger.info("...--test_get_ops_in_non_existent_block--...")
    response = send_request_to_hafah(postgrest_hafah, "get_ops_in_block", block_num=-1)
    assert len(response["ops"]) == 0

