import pytest
import test_tools as tt

from hafah_local_tools import send_request_to_hafah


def test_default_args_value(postgrest_hafah):
    response = send_request_to_hafah(postgrest_hafah, "get_ops_in_block")
    assert len(response["ops"]) == 0


@pytest.mark.parametrize("only_virtual, number_of_ops", ((False, 3), (True, 2)))
def test_filter_virtual_ops(postgrest_hafah, wallet, only_virtual, number_of_ops):
    block_number = wallet.create_account(f"alice-{int(only_virtual)}")["block_num"]
    response = send_request_to_hafah(
        postgrest_hafah,
        "get_ops_in_block",
        block_num=block_number,
        only_virtual=only_virtual,
        include_reversible=True,
    )
    assert len(response["ops"]) == number_of_ops


@pytest.mark.parametrize(
    "include_reversible, comparison_type", ((False, "__eq__"), (True, "__gt__"))
)
def test_get_operations_in_block_with_and_without_reversible(
    postgrest_hafah, include_reversible, comparison_type
):
    response = send_request_to_hafah(
        postgrest_hafah,
        "get_ops_in_block",
        block_num=1,
        only_virtual=False,
        include_reversible=include_reversible,
    )
    assert getattr(len(response["ops"]), comparison_type)(0)


def test_get_ops_in_non_existent_block(postgrest_hafah):
    response = send_request_to_hafah(postgrest_hafah, "get_ops_in_block", block_num=-1)
    assert len(response["ops"]) == 0
