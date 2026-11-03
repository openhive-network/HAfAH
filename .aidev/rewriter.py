"""The postgrest-rewriter (Dockerfile.rewriter) in front of a PostgREST, for the rewriter step.

The runtime image has no nginx, so this does what docker/hafah_rest_nginx.conf.template makes
the rewriter image do, in the same order:

1. `$path_filters`: each `path-filter=` value of the query string, unescaped and base64-encoded,
   as a PostgreSQL array literal; then those parameters are dropped from the query string;
2. endpoints/rewrite_rules.conf: the rules in file order, the first whose regex matches the
   decoded path wins (each ends in `break`), `$N` is the Nth capture and `$path_filters` the
   value above, and a replacement with a query of its own gets the request's remaining
   arguments appended to it;
3. the rewrite_by_lua_block: a GET of a `/rpc/` function goes upstream as a form-encoded POST
   whose body is the query string, except PostgREST's reserved parameters (`limit`, `offset`,
   `order`, `select`, ...), which stay in the query string.

The rewriter receives the paths the API node's reverse proxy leaves after stripping the public
`/hafah-api` prefix, and so does this.
"""
import base64
import http.client
import re
import threading
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import quote, unquote, unquote_plus, unquote_to_bytes, urlsplit

_RULE_RE = re.compile(r"rewrite\s+(\S+)\s+(\S+)\s+break;")
_VARIABLE_RE = re.compile(r"\$(\d|path_filters)")
_PATH_FILTER_RE = re.compile(r"path-filter=([^&]*)")
_PATH_FILTER_PARAM_RE = re.compile(r"&?path-filter=[^&]*")
# What nginx's NGX_ESCAPE_ARGS leaves as it is in a capture copied into the arguments.
_ARGS_SAFE = "".join(chr(c) for c in range(0x21, 0x7F) if chr(c) not in "#%&+?")
# Query parameters PostgREST reserves, by name and by last dot-separated part of the name.
_RESERVED = {"select", "columns", "on_conflict"}
_RESERVED_LAST = {"limit", "offset", "order", "and", "or"}
# Headers http.client sets itself or that describe one hop only.
_HOP_HEADERS = {"connection", "keep-alive", "transfer-encoding", "host", "content-length"}


def _load_rules(text: str) -> list[tuple[re.Pattern[str], str]]:
    """The `rewrite REGEX REPLACEMENT break;` rules of rewrite_rules.conf, in order.

    Raises ValueError on any other directive, which this would not apply as nginx does.
    """
    rules = []
    for number, line in enumerate(text.splitlines(), 1):
        line = line.strip()
        if not line or line.startswith("#"):
            continue
        match = _RULE_RE.fullmatch(line)
        if match is None:
            raise ValueError(f"rewrite_rules.conf:{number}: not a `rewrite REGEX REPLACEMENT break;` rule: {line}")
        rules.append((re.compile(match.group(1)), match.group(2)))
    return rules


def _path_filters(args: str) -> str:
    encoded = [base64.b64encode(unquote_to_bytes(value.replace("+", " "))).decode()
               for value in _PATH_FILTER_RE.findall(args)]
    return "{" + ",".join(encoded) + "}"


def _rewrite(rules: list[tuple[re.Pattern[str], str]], target: str) -> str:
    """The request target (path and query) the rewrite rules make of `target`."""
    split = urlsplit(target)
    path = unquote(split.path)
    path_filters = _path_filters(split.query)
    args = _PATH_FILTER_PARAM_RE.sub("", split.query)
    # nginx escapes a capture it copies into the arguments when the request's path was escaped.
    escape = "%" in split.path or "+" in split.path
    for regex, replacement in rules:
        match = regex.search(path)
        if match is None:
            continue
        new_path, has_args, new_args = replacement.partition("?")

        def substitute(variable: re.Match[str], in_args: bool) -> str:
            if variable.group(1) == "path_filters":
                return path_filters
            capture = match.group(int(variable.group(1))) or ""
            return quote(capture, safe=_ARGS_SAFE) if in_args and escape else capture

        new_path = quote(_VARIABLE_RE.sub(lambda v: substitute(v, False), new_path), safe="/")
        if has_args:
            new_args = _VARIABLE_RE.sub(lambda v: substitute(v, True), new_args)
            return f"{new_path}?{new_args}&{args}" if args else f"{new_path}?{new_args}"
        return f"{new_path}?{args}" if args else new_path
    return f"{split.path}?{args}" if args else split.path


def _is_reserved(part: str) -> bool:
    name = unquote_plus(part.partition("=")[0])
    return name in _RESERVED or name.rpartition(".")[2] in _RESERVED_LAST


def _upstream_request(method: str, target: str) -> tuple[str, str, bytes | None]:
    """The method, target and form body the rewriter sends upstream for a `method` of rewritten `target`."""
    path, _, query = target.partition("?")
    if method == "GET" and path.startswith("/rpc/"):
        parts = [part for part in query.split("&") if part]
        reserved = "&".join(part for part in parts if _is_reserved(part))
        body = "&".join(part for part in parts if not _is_reserved(part))
        return "POST", f"{path}?{reserved}" if reserved else path, body.encode()
    return method, target, None


def start(rules_text: str, upstream_host: str, upstream_port: int, port: int) -> ThreadingHTTPServer:
    """Serves the rewriter on 127.0.0.1:`port` in a daemon thread; shut it down with .shutdown()."""
    rules = _load_rules(rules_text)

    class Handler(BaseHTTPRequestHandler):
        def _proxy(self) -> None:
            body: bytes | None = self.rfile.read(int(self.headers.get("Content-Length") or 0)) or None
            headers = {name: value for name, value in self.headers.items() if name.lower() not in _HOP_HEADERS}
            method, target, form = _upstream_request(self.command, _rewrite(rules, self.path))
            if form is not None:
                body = form
                headers = {name: value for name, value in headers.items() if name.lower() != "content-type"}
                headers["Content-Type"] = "application/x-www-form-urlencoded"
            connection = http.client.HTTPConnection(upstream_host, upstream_port, timeout=120)
            try:
                connection.request(method, target, body=body, headers=headers)
                response = connection.getresponse()
                payload = response.read()
            finally:
                connection.close()
            self.send_response(response.status)
            for name, value in response.getheaders():
                if name.lower() not in _HOP_HEADERS:
                    self.send_header(name, value)
            self.send_header("Content-Length", str(len(payload)))
            self.end_headers()
            self.wfile.write(payload)

        do_GET = do_POST = _proxy

        def log_message(self, format: str, *args: object) -> None:
            pass

    server = ThreadingHTTPServer(("127.0.0.1", port), Handler)
    threading.Thread(target=server.serve_forever, daemon=True).start()
    return server
