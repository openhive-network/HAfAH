#!/usr/bin/python3

from distutils.util import strtobool
from sys import argv
from argparse import ArgumentParser
from pathlib import Path
from random import random

engine = ArgumentParser(prog=Path(__file__).parts[-1])
engine.add_argument('-e', '--enum', dest='enum', type=strtobool, nargs='?', const=True, default=False, help="generates filters for `enum_virtual_ops`")
engine.add_argument('-f', '--filter-input', dest='ifilter', type=int, default=0, required=False, help="if given, this will be set at begin")
engine.add_argument('-q', '--quit', dest='quit', type=strtobool, nargs='?', const=True, default=False, help="do not enter CLI mode, handy for translate only with -f option")
args = engine.parse_args(list(argv[1:]))

FIRST_VOP = 'fill_convert_request_operation'
OPERATION_NAMES = [
    "vote_operation",
    "comment_operation",
    "transfer_operation",
    "transfer_to_vesting_operation",
    "withdraw_vesting_operation",
    "limit_order_create_operation",
    "limit_order_cancel_operation",
    "feed_publish_operation",
    "convert_operation",
    "account_create_operation",
    "account_update_operation",
    "witness_update_operation",
    "account_witness_vote_operation",
    "account_witness_proxy_operation",
    "pow_operation",
    "custom_operation",
    "report_over_production_operation",
    "delete_comment_operation",
    "custom_json_operation",
    "comment_options_operation",
    "set_withdraw_vesting_route_operation",
    "limit_order_create2_operation",
    "claim_account_operation",
    "create_claimed_account_operation",
    "request_account_recovery_operation",
    "recover_account_operation",
    "change_recovery_account_operation",
    "escrow_transfer_operation",
    "escrow_dispute_operation",
    "escrow_release_operation",
    "pow2_operation",
    "escrow_approve_operation",
    "transfer_to_savings_operation",
    "transfer_from_savings_operation",
    "cancel_transfer_from_savings_operation",
    "custom_binary_operation",
    "decline_voting_rights_operation",
    "reset_account_operation",
    "set_reset_account_operation",
    "claim_reward_balance_operation",
    "delegate_vesting_shares_operation",
    "account_create_with_delegation_operation",
    "witness_set_properties_operation",
    "account_update2_operation",
    "create_proposal_operation",
    "update_proposal_votes_operation",
    "remove_proposal_operation",
    "update_proposal_operation",
    "collateralized_convert_operation",
    "recurrent_transfer_operation",
    "fill_convert_request_operation",
    "author_reward_operation",
    "curation_reward_operation",
    "comment_reward_operation",
    "liquidity_reward_operation",
    "interest_operation",
    "fill_vesting_withdraw_operation",
    "fill_order_operation",
    "shutdown_witness_operation",
    "fill_transfer_from_savings_operation",
    "hardfork_operation",
    "comment_payout_update_operation",
    "return_vesting_delegation_operation",
    "comment_benefactor_reward_operation",
    "producer_reward_operation",
    "clear_null_account_balance_operation",
    "proposal_pay_operation",
    "sps_fund_operation",
    "hardfork_hive_operation",
    "hardfork_hive_restore_operation",
    "delayed_voting_operation",
    "consolidate_treasury_balance_operation",
    "effective_comment_vote_operation",
    "ineffective_delete_comment_operation",
    "sps_convert_operation",
    "expired_account_notification_operation",
    "changed_recovery_account_operation",
    "transfer_to_vesting_completed_operation",
    "pow_reward_operation",
    "vesting_shares_split_operation",
    "account_created_operation",
    "fill_collateralized_convert_request_operation",
    "system_warning_operation",
    "fill_recurrent_transfer_operation",
    "failed_recurrent_transfer_operation",
    "limit_order_cancelled_operation"
]

if args.enum:
    first_vop = OPERATION_NAMES.index(FIRST_VOP)
    OPERATION_NAMES = list(OPERATION_NAMES[first_vop:])

operations_ids = { id: name for id, name in enumerate(OPERATION_NAMES) }
filter = args.ifilter

def colored(r, g, b, text):
    return "\033[38;2;{};{};{}m{} \033[38;2;255;255;255m".format(r, g, b, text)

def green(text):
    return colored(0, 255, 0, text)

def white(text):
    return colored(255, 255, 255, text)

def split_high_low(inc):
    high = inc >> 64
    low = inc & ~(high << 64)
    return high, low

def calculate_pow2(exponent : int):
    return 1 << exponent

def print_options():
    global filter
    for id, name in operations_ids.items():
        if name == FIRST_VOP:
            print(f"{'-'*5} virtual operations {'-'*5}", flush=False)
        is_set = bool(filter & calculate_pow2(id))
        color = green if is_set else white
        print(color(f'{id :02}) [{int(is_set)}] {name}'), flush=True)
    print(white(' '), flush=True)

def update_filter(N : int):
    global filter
    filter ^= calculate_pow2(N)

try:
    while True:
        print_options()
        print(f'current filter (dec): {filter}')
        print(f'current filter (dec) [high | low]: {split_high_low(filter)}')
        print(f'current filter (hex): {hex(filter)}')
        print(f'current filter (bin): {bin(filter)}')
        if args.quit: exit(0)
        print('\n' + f'0 - {len(operations_ids)-1} - switches operation type')
        print('`null` - sets filter to zero')
        print('`~` or `!` - negates filter')
        print('`rng` - randomizes filter\n', flush=True)
        inc = input("> ").lower()

        if inc == 'null':
            filter = 0
            continue
        elif inc == 'rng':
            for i in list(operations_ids.keys()):
                if random() >= 0.5:
                    update_filter(i)
            continue
        elif inc == '~' or inc == '!':
            for i in list(operations_ids.keys()):
                update_filter(i)
            continue
        else: inc = int(inc)

        if inc >= 0 and inc < len(OPERATION_NAMES):
            update_filter(inc)
except KeyboardInterrupt:
    print('\nfinished on user request', flush=True)
except Exception as e:
    print(f'got excepiton: {e}')
    exit(-1)
