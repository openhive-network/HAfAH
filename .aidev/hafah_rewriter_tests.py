#!/usr/bin/env python3
"""Run the rewriter tests (tests/rewriter) through the rewriter in front of PostgREST.

    hafah_rewriter_tests.py OUT_DIR

Starts PostgREST over the run's clone (.aidev/postgrest.py) and, in front of it, the rewriter
image's OpenResty with the image's configuration (.aidev/hafah_rewriter.py), then runs pytest
on tests/rewriter with HAFAH_REWRITER_URL and HAFAH_POSTGREST_URL pointing at them. CI and a
manual run can point the same variables at a running rewriter image instead.

Writes OUT_DIR/rewriter.xml (one junit case per test) and the two servers' logs beside it, and
exits with pytest's status.
"""
import os
import subprocess
import sys

import hafah_rewriter
from postgrest import serving

HERE = os.path.dirname(os.path.abspath(__file__))
TESTS = os.path.join(HERE, "..", "tests", "rewriter")


def main(out: str) -> int:
    os.makedirs(out, exist_ok=True)
    with serving(os.path.join(out, "postgrest-rewriter.log")) as base, \
            hafah_rewriter.serving(base, os.path.join(out, "openresty-rewriter.log")) as rewriter:
        print(f"rewriter: {hafah_rewriter.OPENRESTY} with docker/hafah_rest_nginx.conf.template at {rewriter}",
              flush=True)
        env = dict(os.environ, HAFAH_POSTGREST_URL=base, HAFAH_REWRITER_URL=rewriter)
        return subprocess.run(
            [sys.executable, "-m", "pytest", "-p", "no:cacheprovider",
             "--junitxml", os.path.abspath(os.path.join(out, "rewriter.xml")), "."],
            cwd=TESTS, env=env, check=False,
        ).returncode


if __name__ == "__main__":
    if len(sys.argv) != 2:
        sys.exit(f"usage: {sys.argv[0]} OUT_DIR")
    sys.exit(main(sys.argv[1]))
