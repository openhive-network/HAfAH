"""HTTP clients for the rewriter and the PostgREST behind it."""
import json
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any


@dataclass(frozen=True)
class Answer:
    status: int
    body: Any


def _send(request: urllib.request.Request) -> Answer:
    try:
        with urllib.request.urlopen(request, timeout=60) as resp:
            status, raw = resp.status, resp.read()
    except urllib.error.HTTPError as err:
        status, raw = err.code, err.read()
    return Answer(status, json.loads(raw) if raw.strip() else None)


@dataclass(frozen=True)
class Head:
    """An answer's status and the type of its body, which a HEAD answers as its GET would."""
    status: int
    content_type: str | None


@dataclass(frozen=True)
class Rewriter:
    base: str

    def get(self, target: str) -> Answer:
        """GET `target` (path and query, sent as written) through the rewriter."""
        return _send(urllib.request.Request(self.base + target))

    def head(self, target: str, method: str = "HEAD") -> Head:
        """The Head of the answer to a `method` (HEAD unless named) of `target` through the rewriter."""
        request = urllib.request.Request(self.base + target, method=method)
        try:
            with urllib.request.urlopen(request, timeout=60) as resp:
                status, headers = resp.status, resp.headers
        except urllib.error.HTTPError as err:
            status, headers = err.code, err.headers
        return Head(status, headers.get("Content-Type"))


@dataclass(frozen=True)
class PostgREST:
    base: str

    def call(self, function: str, args: dict[str, Any]) -> Answer:
        """Call `function` with `args` in a JSON body, whose fields PostgREST never reads as filters."""
        return _send(urllib.request.Request(f"{self.base}/rpc/{function}", data=json.dumps(args).encode(),
                                            method="POST", headers={"Content-Type": "application/json"}))

    def get(self, function: str, query: str) -> Answer:
        """GET `function` with `query` (sent as written) straight from PostgREST."""
        return _send(urllib.request.Request(f"{self.base}/rpc/{function}?{query}"))
