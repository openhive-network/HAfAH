"""The REST API as clients reach it, through the postgrest-rewriter, and PostgREST behind it.

HAFAH_REWRITER_URL is the rewriter, which receives the paths the API node leaves after
stripping the public `/hafah-api` prefix; HAFAH_POSTGREST_URL is the PostgREST it forwards to.
Expected values are the chain's up to block 5000000.
"""
import os

import pytest
from rest_client import PostgREST, Rewriter


@pytest.fixture(scope="session")
def rewriter() -> Rewriter:
    return Rewriter(os.environ["HAFAH_REWRITER_URL"])


@pytest.fixture(scope="session")
def postgrest() -> PostgREST:
    return PostgREST(os.environ["HAFAH_POSTGREST_URL"])
