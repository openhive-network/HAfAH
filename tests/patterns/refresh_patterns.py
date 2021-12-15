#!/usr/bin/env python3

import os

from os.path import join
import yaml
import json
import requests
from sys import argv
from argparse import ArgumentParser
from concurrent.futures import ProcessPoolExecutor


def load_yaml(filename : str) -> dict:
    with open(filename, 'rt') as file:
        return yaml.load(file, yaml.Loader)


def create_pattern(url: str, tav_file: str, directory: str):
    PATTERN_FILE = tav_file.split('.')[0] + '.pat.json'
    TAVERN_FILE = join(directory, tav_file)
    OUTPUT_PATTERN_FILE = join(directory, f'{PATTERN_FILE}')
    print(f'creating pattern {OUTPUT_PATTERN_FILE}')

    test_options = load_yaml(TAVERN_FILE)
    request = test_options['stages'][0]['request']
    output = requests.post(url, json=request['json'], headers=request['headers'])
    assert output.status_code == 200
    parsed = output.json()

    if '_negative' in directory:
        assert 'error' in parsed, f'while processing {TAVERN_FILE}, no "error" found in response: {parsed}'
        return
    else:
        assert 'result' in parsed, f'while processing {TAVERN_FILE}, no "result" found in response: {parsed}' + '\n' + f'{request}'

    with open(OUTPUT_PATTERN_FILE, 'wt') as file:
        json.dump(parsed, file, indent=2, sort_keys=True)
        file.write('\n')


def main(URL: str):
    futures = []
    with ProcessPoolExecutor(max_workers=6) as exec:
        for parent_path, _, filenames in os.walk('.'):
            if 'tavern' in parent_path and 'account_history_api' in parent_path:
                for tavernfile in filter(lambda x: x.endswith('tavern.yaml'), filenames):
                    create_pattern(URL, tavernfile, parent_path)
                    # futures.append( exec.submit(create_pattern, URL, tavernfile, parent_path) )

        for future in futures:
            future.result()


if __name__ == '__main__':
    parser = ArgumentParser()
    parser.add_argument('URL', type=str, help='reference account history endpoint, which will provide pattern data (Ex. http://localhost:6543)')
    args = parser.parse_args(argv[1:])

    main(args.URL)
