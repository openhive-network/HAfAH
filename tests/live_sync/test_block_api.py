import test_tools as tt


def test_get_block_header(apis):
    hafah, node = apis
    head_block_number = node.api.database.get_dynamic_global_properties()["head_block_number"]

    response = hafah.api.block.get_block_header(block_num=head_block_number)
    tt.logger.info(f'response {response}')
    

def test_get_block(apis):
    hafah, node = apis
    head_block_number = node.api.database.get_dynamic_global_properties()["head_block_number"]

    response = hafah.api.block.get_block(block_num=head_block_number)
    tt.logger.info(f'response {response}')


def test_get_block_range(apis):
    hafah, node = apis
    head_block_number = node.api.database.get_dynamic_global_properties()["head_block_number"]

    response = hafah.api.block.get_block_range(starting_block_num=head_block_number-10, count=1000)
    tt.logger.info(f'hafah {response}')
