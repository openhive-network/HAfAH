#!/usr/bin/python3

from distutils.util import strtobool
from sys import argv
from argparse import ArgumentParser
from pathlib import Path
from random import random

engine = ArgumentParser(prog=Path(__file__).parts[-1])
engine.add_argument(
    "-e",
    "--enum",
    dest="enum",
    type=strtobool,
    nargs="?",
    const=True,
    default=False,
    help="generates filters for `enum_virtual_ops`",
)
engine.add_argument(
    "-f",
    "--filter-input",
    dest="ifilter",
    type=int,
    default=0,
    required=False,
    help="if given, this will be set at begin",
)
engine.add_argument(
    "-q",
    "--quit",
    dest="quit",
    type=strtobool,
    nargs="?",
    const=True,
    default=False,
    help="do not enter CLI mode, handy for translate only with -f option",
)
args = engine.parse_args(list(argv[1:]))


def get_operations_from_operations_hpp() -> list[str]:
    path_to_operations_hpp = (
        Path(__file__).parent.parent.absolute()
        / "haf"
        / "hive"
        / "libraries"
        / "protocol"
        / "include"
        / "hive"
        / "protocol"
        / "operations.hpp"
    )
    assert (
        path_to_operations_hpp.exists()
    ), f"{path_to_operations_hpp.as_posix()} does not exists"
    operations = []
    with path_to_operations_hpp.open() as file:
        begin_of_operation = "typedef fc::static_variant<"
        end_of_operations = "> operation;"
        begin_of_smt = "#ifdef HIVE_ENABLE_SMT"
        end_of_smt = "#endif"
        smt_skipped = False
        smt_in_progress = False
        operations_lines_started = False
        for line in file:
            if not operations_lines_started:
                if begin_of_operation in line:
                    operations_lines_started = True
                continue

            if end_of_operations in line:
                break

            if smt_in_progress:
                if end_of_smt in line:
                    smt_in_progress = False
                    smt_skipped = True
                continue

            if not smt_skipped and begin_of_smt in line:
                smt_in_progress = True
                continue

            line = line.strip(" \n/")
            if len(line) == 0 or "_operation" not in line:
                continue

            operations.append(line.split(" ")[0].strip(","))
        return operations


FIRST_VOP = "fill_convert_request_operation"
OPERATION_NAMES = get_operations_from_operations_hpp()

if args.enum:
    first_vop = OPERATION_NAMES.index(FIRST_VOP)
    OPERATION_NAMES = list(OPERATION_NAMES[first_vop:])

operations_ids = {id: name for id, name in enumerate(OPERATION_NAMES)}
filter = args.ifilter


def colored(r: int, g: int, b: int, text: str) -> str:
    return f"\033[38;2;{r};{g};{b}m{text} \033[38;2;255;255;255m"


def green(text: str) -> None:
    print(colored(0, 255, 0, text), flush=True)


def white(text: str) -> None:
    print(colored(255, 255, 255, text), flush=True)


def split_high_low(inc: int) -> tuple[int, int]:
    high = inc >> 64
    low = inc & ~(high << 64)
    return high, low


def calculate_pow2(exponent: int) -> int:
    return 1 << exponent


def print_options() -> None:
    global filter
    for id, name in operations_ids.items():
        if name == FIRST_VOP:
            white(f"{'-'*5} virtual operations {'-'*5}")
        is_set = bool(filter & calculate_pow2(id))
        color = green if is_set else white
        color(f"{id :02}) [{int(is_set)}] {name}")
    white(" ")


def update_filter(n: int) -> None:
    global filter
    filter ^= calculate_pow2(n)


try:
    while True:
        print_options()
        print(f"current filter (dec): {filter}")
        print(f"current filter (dec) [high | low]: {split_high_low(filter)}")
        print(f"current filter (hex): {hex(filter)}")
        print(f"current filter (bin): {bin(filter)}")
        if args.quit:
            exit(0)
        print("\n" + f"0 - {len(operations_ids)-1} - switches operation type")
        print("`null` - sets filter to zero")
        print("`~` or `!` - negates filter")
        print("`rng` - randomizes filter\n", flush=True)
        inc = input("> ").lower()

        if inc == "null":
            filter = 0
            continue
        elif inc == "rng":
            for i in list(operations_ids.keys()):
                if random() >= 0.5:
                    update_filter(i)
            continue
        elif inc == "~" or inc == "!":
            for i in list(operations_ids.keys()):
                update_filter(i)
            continue
        else:
            try:
                inc = int(inc)
            except ValueError:
                print(f"unknown option: `{inc}`; try again!")
                continue

        if inc >= 0 and inc < len(OPERATION_NAMES):
            update_filter(inc)
except KeyboardInterrupt:
    print("\nfinished on user request", flush=True)
except Exception as e:
    print(f"got exception: {e}")
    exit(-1)
