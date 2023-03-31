import os
import subprocess
import time
import random
from pathlib import Path
from typing import Iterable
import pytest

from functools import partial
from concurrent.futures import ThreadPoolExecutor, as_completed

import test_tools as tt

import shared_tools.complex_networks_helper_functions as sh
from haf_local_tools import haf_app

START_TEST_BLOCK    = 108
memo_cnt            = 0


def haf_app_processor(identifier, before_kill_time_min, before_kill_time_max):
    while True:
        _app = haf_app(identifier, before_kill_time_min, before_kill_time_max)
        tt.logger.info( f"app runs: {identifier}")
        _app.run()

def fork_activator(networks: Iterable[tt.Network], logs, majority_api_node, _m, _M):
    _cnt = 1

    while True:
        tt.logger.info(f'Disconnect sub networks: {_cnt}...')
        sh.disconnect_sub_networks(networks)

        sh.wait(5, logs, majority_api_node)

        _last_lib_M = sh.get_last_irreversible_block_num(_M)
        tt.logger.info(f'last Lib: {_last_lib_M}...')

        tt.logger.info(f'Reconnect sub networks: {_cnt}...')
        sh.connect_sub_networks(networks)

        sh.wait_for_final_block(majority_api_node, logs, [_m, _M], True, partial(sh.lib_custom_condition, _M, _last_lib_M), False)
        tt.logger.info(f'Sub networks reconnected: {_cnt}...')

        _cnt += 1

def trx_creator(wallet):
    global memo_cnt
    while True:
        wallet.api.transfer_nonblocking('initminer', 'null', tt.Asset.Test(1), str(memo_cnt))
        memo_cnt += 1

@pytest.mark.skip(reason='https://gitlab.syncad.com/hive/haf/-/issues/118')
def test_many_forks_many_ops(prepared_networks_and_database_17_3):

    tt.logger.info(f'Start test_many_forks_many_ops')

    networks_builder, session = prepared_networks_and_database_17_3

    haf_app.setup(session, Path(__file__).parent.absolute() / ".." / ".." / ".." / ".." / "src" / "hive_fork_manager" / "doc" / "applications")

    majority_api_node = networks_builder.networks[0].node('ApiNode0')
    minority_api_node = networks_builder.networks[1].node('ApiNode1')

    minority_api_node.wait_for_block_with_number(START_TEST_BLOCK)

    logs = []

    majority_wallet = tt.Wallet(attach_to = majority_api_node)
    minority_wallet = tt.Wallet(attach_to = minority_api_node)
    logs.append(sh.NodeLog("M", majority_wallet))
    logs.append(sh.NodeLog("m", minority_wallet))

    _M = logs[0].collector
    _m = logs[1].collector

    blocks_before_disconnect = 5

    tt.logger.info(f'Before disconnecting...')
    cnt = 0
    while True:
        sh.wait(1, logs, majority_api_node)

        cnt += 1
        if cnt > blocks_before_disconnect:
            if sh.get_last_irreversible_block_num(_M) == sh.get_last_irreversible_block_num(_m):
                break

    _futures = []
    _fork_threads = 1
    _push_threads = 2
    _app_threads  = 1
    with ThreadPoolExecutor(max_workers = _fork_threads + _push_threads + _app_threads ) as executor:
        _futures.append(executor.submit(fork_activator, networks_builder.networks, logs, majority_api_node, _m, _M))

        for i in range(_push_threads):
            if i % 2 == 0:
                _futures.append(executor.submit(trx_creator, majority_wallet))
            else:
                _futures.append(executor.submit(trx_creator, minority_wallet))

        for i in range(_app_threads):
            _futures.append(executor.submit(haf_app_processor, i, 5, 30 ))

    for future in as_completed(_futures):
        future.result()
