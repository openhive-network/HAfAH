import test_tools as tt


def test_get_ops_in_block(apis):
    hafah, node = apis
    head_block_number = node.api.database.get_dynamic_global_properties()["head_block_number"]

    response = hafah.api.account_history.get_ops_in_block(block_num=head_block_number, only_virtual=False, include_reversible=True)
    tt.logger.info(f'response {response}')

    response = hafah.api.account_history.get_ops_in_block(block_num=head_block_number-20, only_virtual=False, include_reversible=True)
    tt.logger.info(f'response {response}')


def test_get_transaction(apis):
    hafah, node = apis

    wallet = tt.Wallet(attach_to=node)
    # this private key was used to convert block_log to mirrornet
    wallet.api.import_key("5JNHfZYKGaomSFvd4NUdQ9qMcEAC43kujbfjueTHpVapX1Kzq2n")

    transaction = wallet.api.create_account('blocktrades', 'zxcasdqwe123', '')
    tt.logger.info(f'transaction {transaction}')

    response = hafah.api.account_history.get_transaction(id=transaction["transaction_id"], include_reversible=True)
    tt.logger.info(f'response {response}')


def test_get_account_history(apis):
    hafah, node = apis

    response = hafah.api.account_history.get_account_history(account='blocktrades', start=-1, limit=1000, include_reversible=True)
    tt.logger.info(f'response {response}')

    current_witness = node.api.database.get_dynamic_global_properties()["current_witness"]
    tt.logger.info(f'response {current_witness}')

    response = hafah.api.account_history.get_account_history(account=current_witness, start=-1, limit=1000, include_reversible=True)
    tt.logger.info(f'response {response}')


def test_enum_virtual_ops(apis):
    hafah, node = apis
    head_block_number = node.api.database.get_dynamic_global_properties()["head_block_number"]

    response = hafah.api.account_history.enum_virtual_ops(block_range_begin=head_block_number-50, block_range_end=head_block_number, include_reversible=True)
    tt.logger.info(f'response {response}')

    response = hafah.api.account_history.enum_virtual_ops(block_range_begin=1000, block_range_end=2000, include_reversible=True)
    tt.logger.info(f'response {response}')
