# Example usage: pytest -s -n 4 test_account_history.py --ref localhost:8091 --test localhost:8095 --hashes /path/to/hashes.csv -v

from pytest import fixture, mark
from typing import Generator
from test_tools import RemoteNode

pytestmark = mark.asyncio

@fixture
def ref_node(request) -> RemoteNode:
	return RemoteNode(request.config.getoption("--ref"))

@fixture
def test_node(request) -> RemoteNode:
	return RemoteNode(request.config.getoption("--test"))

@fixture
def transactions(request) -> list:
	from os.path import exists
	path = request.config.getoption("--hashes")
	assert exists(path)
	with open(path, 'rt') as file:
		return [x.strip() for x in file.readlines()]

@fixture
def accounts(ref_node : RemoteNode) -> list:
	LIMIT = 1_000
	all_accounts = []
	last_account = None


	while True:
		result = ref_node.api.database.list_accounts(start=last_account, order="by_name" ,limit=LIMIT)['result']
		all_accounts.extend( [ x['name'] for x in result['accounts'] ] )
		if len(result) < LIMIT: break
		last_account = all_accounts[-1]

	return all_accounts

@fixture
def block_range():
	return range(4_900_000, 4_905_000)

def compare(ref_node : RemoteNode, test_node : RemoteNode, foo) -> bool:
	assert foo(ref_node) == foo(test_node)


async def test_get_transactions(ref_node : RemoteNode, test_node : RemoteNode, transactions : list):
	for trx in transactions:
		compare(ref_node, test_node, lambda x : x.api.account_history.get_transaction(
			id=trx,
			include_reversible=True
		))

async def test_get_account_history(ref_node : RemoteNode, test_node : RemoteNode, accounts : list):
	for account in accounts:
		compare(ref_node, test_node, lambda x : x.api.account_history.get_account_history(
			account=account,
			start=-1,
			limit=1_000,
			include_reversible=True
		))

async def test_get_ops_in_block(ref_node : RemoteNode, test_node : RemoteNode, block_range : Generator):
	for bn in block_range:
		compare(ref_node, test_node, lambda x : x.api.account_history.get_ops_in_block(
			block_num=bn,
			only_virtual=False,
			include_reversible=True
		))

async def test_enum_virtual_ops(ref_node : RemoteNode, test_node : RemoteNode, block_range : Generator):
	for bn in block_range:
		compare(ref_node, test_node, lambda x : x.api.account_history.enum_virtual_ops(
			block_range_begin=bn,
			block_range_end=bn+1,
			include_reversible=True,
			group_by_block=False,
			limit=1_000,
			operation_begin=0
		))
