#!/usr/bin/env python3
"""Run the rewriter tests (tests/rewriter) through the rewriter in front of PostgREST.

    hafah_rewriter_tests.py OUT_DIR

Starts PostgREST over the run's clone (.aidev/postgrest.py) and the rewriter emulator in front
of it (.aidev/rewriter.py, with endpoints/rewrite_rules.conf), then runs pytest on
tests/rewriter with HAFAH_REWRITER_URL and HAFAH_POSTGREST_URL pointing at them. CI and a
manual run can point the same variables at the rewriter image instead.

Writes OUT_DIR/rewriter.xml (one junit case per test) and exits with pytest's status.
"""
import os
import subprocess
import sys

import rewriter
from postgrest import free_port, serving

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.join(HERE, "..", "tests", "rewriter")
RULES = os.path.join(HERE, "..", "endpoints", "rewrite_rules.conf")


def main(out: str) -> int:
    os.makedirs(out, exist_ok=True)
    with open(RULES) as rules, serving(os.path.join(out, "postgrest-rewriter.log")) as base:
        host, port = base.removeprefix("http://").rsplit(":", 1)
        rewriter_port = free_port()
        server = rewriter.start(rules.read(), host, int(port), rewriter_port)
        try:
            env = dict(os.environ, HAFAH_POSTGREST_URL=base, HAFAH_REWRITER_URL=f"http://127.0.0.1:{rewriter_port}")
            return subprocess.run(
                [sys.executable, "-m", "pytest", "-p", "no:cacheprovider",
                 "--junitxml", os.path.abspath(os.path.join(out, "rewriter.xml")), "."],
                cwd=TESTS, env=env, check=False,
            ).returncode
        finally:
            server.shutdown()


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} OUT_DIR")
    sys.exit(main(sys.argv[1]))
