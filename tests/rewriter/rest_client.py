"""HTTP clients for the rewriter and the PostgREST behind it."""
import http.client
import io
import json
import socket
import urllib.error
import urllib.request
from dataclasses import dataclass
from typing import Any
from urllib.parse import urlsplit


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


class _SharedReader(io.BufferedReader):
    """One reader for every answer on a connection.

    http.client gives each answer a reader of its own and drops whatever that reader buffered
    past the answer's framing, so bytes a server sent after a HEAD's headers would vanish
    rather than be read as the start of the next answer, as a proxy reusing the connection reads them.
    """

    def close(self) -> None:
        """Leave the reader open for the next answer; release() closes it."""

    def release(self) -> None:
        super().close()


def _answers_from(reader: _SharedReader) -> type[http.client.HTTPResponse]:
    """An answer class reading from `reader` instead of a reader of its own."""
    class _Answer(http.client.HTTPResponse):
        def __init__(self, sock: socket.socket, debuglevel: int = 0, method: str | None = None,
                     url: str | None = None) -> None:
            super().__init__(sock, debuglevel, method, url)
            self.fp.close()
            self.fp = reader
    return _Answer


@dataclass(frozen=True)
class Raw:
    """An answer as it came off the connection: status, headers and every body byte read."""
    status: int
    headers: dict[str, str]
    body: bytes


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

    def in_turn(self, *requests: tuple[str, str]) -> list[Raw]:
        """Send each (method, target) in turn on one HTTP/1.1 keep-alive connection, reading each answer fully.

        Raises http.client.HTTPException when an answer is not where the previous one's framing ends.
        """
        conn = http.client.HTTPConnection(urlsplit(self.base).netloc, timeout=60)
        conn.auto_open = 0
        conn.connect()
        reader = _SharedReader(socket.SocketIO(conn.sock, "rb"))
        conn.response_class = _answers_from(reader)
        try:
            answers = []
            for method, target in requests:
                conn.request(method, target)
                resp = conn.getresponse()
                answers.append(Raw(resp.status, dict(resp.getheaders()), resp.read()))
            return answers
        finally:
            reader.release()
            conn.close()


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
