import test_tools as tt

from haf_local_tools import make_fork, wait_for_irreversible_progress, create_node_with_database
from haf_local_tools.tables import Blocks, Transactions, Operations


START_TEST_BLOCK = 108


def test_compare_forked_node_database(prepared_networks_and_database_12_8, database):
    tt.logger.info(f'Start test_compare_forked_node_database')

    # GIVEN
    networks_builder, session = prepared_networks_and_database_12_8
    node_under_test = networks_builder.networks[1].node('ApiNode0')

    session_ref = database('postgresql:///haf_block_log_ref')

    create_node_with_database(networks_builder.networks[0], session_ref.get_bind().url)

    # WHEN
    node_under_test.wait_for_block_with_number(START_TEST_BLOCK)
    wallet = tt.Wallet(attach_to=node_under_test)
    transaction1 = wallet.api.transfer('initminer', 'null', tt.Asset.Test(1234), 'memo', broadcast=False)
    transaction2 = wallet.api.transfer_to_vesting('initminer', 'null', tt.Asset.Test(1234), broadcast=False)
    after_fork_block = make_fork(
        networks_builder.networks,
        main_chain_trxs=[transaction1],
        fork_chain_trxs=[transaction2],
    )

    # THEN
    wait_for_irreversible_progress(node_under_test, after_fork_block)

    blks = session.query(Blocks).filter(Blocks.num < after_fork_block).order_by(Blocks.num).all()
    blks_ref = session_ref.query(Blocks).filter(Blocks.num < after_fork_block).order_by(Blocks.num).all()

    for block, block_ref in zip(blks, blks_ref):
        assert block.hash == block_ref.hash

    trxs = session.query(Transactions).filter(Transactions.block_num < after_fork_block).order_by(Transactions.trx_hash).all()
    trxs_ref = session_ref.query(Transactions).filter(Transactions.block_num < after_fork_block).order_by(Transactions.trx_hash).all()

    for trx, trx_ref in zip(trxs, trxs_ref):
        assert trx.trx_hash == trx_ref.trx_hash

    ops = session.query(Operations).filter(Operations.block_num < after_fork_block).order_by(Operations.id).all()
    ops_ref = session_ref.query(Operations).filter(Operations.block_num < after_fork_block).order_by(Operations.id).all()

    for op, op_ref in zip(ops, ops_ref):
        assert op.body == op_ref.body
