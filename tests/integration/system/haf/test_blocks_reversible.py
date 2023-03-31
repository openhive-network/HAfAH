import test_tools as tt

from haf_local_tools import make_fork, wait_for_irreversible_progress
from haf_local_tools.tables import BlocksReversible


START_TEST_BLOCK = 108


def test_blocks_reversible(prepared_networks_and_database_12_8):
    tt.logger.info(f'Start test_blocks_reversible')

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8
    node_under_test = networks_builder.networks[1].node('ApiNode0')

    # WHEN
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    after_fork_block = make_fork(networks_builder.networks)

    # THEN
    irreversible_block_num, head_block_number = wait_for_irreversible_progress(node_under_test, after_fork_block+1)

    blks = session.query(BlocksReversible).order_by(BlocksReversible.num).all()
    block_nums_reversible = [block.num for block in blks]
    assert sorted(block_nums_reversible) == [i for i in range(irreversible_block_num, head_block_number)]
