# Usage

To run tavern test:
1. Enter `tavern` directory
2. Edit `common.yaml` and set variables to desired values
3. Install tavern/pytest `pip install tavern[pytest]`
4. Run tests: `PYTHONPATH=$PYTHONPATH:$(pwd) py.test -v`
   or with compact logging: `PYTHONPATH=$PYTHONPATH:/home/dariusz-work/Sources/tests_api/hivemind/tavern/ py.test -v -tavern-beta-new-traceback -p no:logging`


Each test is marked, we have three mark defined:
1. failing: Mark failing tests
2. patterntest: Mark tests using patterns to compare results
3. smoketest: Mark smoke tests

To run marked tests use following commands:

1. This will run test not marked as `failing`
`PYTHONPATH=$PYTHONPATH:/home/dariusz-work/Sources/tests_api/hivemind/tavern/ py.test test_condenser_api_patterns.tavern.yaml -v --tavern-beta-new-traceback -p no:logging -m "not failing"`

2. This will run only `failing` tests
`PYTHONPATH=$PYTHONPATH:/home/dariusz-work/Sources/tests_api/hivemind/tavern/ py.test test_condenser_api_patterns.tavern.yaml -v --tavern-beta-new-traceback -p no:logging -m "failing"`

