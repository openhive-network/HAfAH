"""The postgrest-rewriter (Dockerfile.rewriter) in front of a PostgREST, for the rewriter step.

The runtime image carries the OpenResty of Dockerfile.rewriter's base image
(.aidev/runtime/Dockerfile). This gives it what Dockerfile.rewriter copies in -
docker/hafah_rest_nginx.conf.template as nginx.conf, with docker/rewriter_entrypoint.sh's
`${REWRITE_LOG}` substitution for REWRITE_LOG=on, and endpoints/rewrite_rules.conf beside it - in a scratch
prefix, and changes only where it listens and what it forwards to: the checks run
unprivileged, beside a PostgREST on a free loopback port rather than `hafah-postgrest:3000`.
"""
import contextlib
import os
import shutil
import socket
import subprocess
import tempfile
import time
from collections.abc import Iterator

from postgrest import free_port

OPENRESTY = "/usr/local/openresty/bin/openresty"
STARTUP_TIMEOUT_S = 30

_ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..")
_TEMPLATE = os.path.join(_ROOT, "docker", "hafah_rest_nginx.conf.template")
_RULES = os.path.join(_ROOT, "endpoints", "rewrite_rules.conf")
_REWRITE_LOG = "rewrite_log on;"
_UPSTREAM = "http://hafah-postgrest:3000"


def _replace_once(text: str, old: str, new: str) -> str:
    if text.count(old) != 1:
        raise ValueError(f"{_TEMPLATE}: expected `{old}` once, found it {text.count(old)} times")
    return text.replace(old, new)


def _config(upstream: str, port: int, health_port: int) -> str:
    with open(_TEMPLATE) as template:
        text = template.read()
    # As the entrypoint's sed does: every occurrence, the template's comment naming it too.
    text = text.replace("${REWRITE_LOG}", _REWRITE_LOG)
    text = _replace_once(text, "listen 0.0.0.0:80 default_server;", f"listen 127.0.0.1:{port} default_server;")
    text = _replace_once(text, "listen 0.0.0.0:81;", f"listen 127.0.0.1:{health_port};")
    return _replace_once(text, f"proxy_pass  {_UPSTREAM};", f"proxy_pass  {upstream};")


def _listening(port: int) -> bool:
    with contextlib.suppress(OSError), socket.create_connection(("127.0.0.1", port), timeout=1):
        return True
    return False


@contextlib.contextmanager
def serving(upstream: str, log_path: str) -> Iterator[str]:
    """Run the rewriter in front of the PostgREST at `upstream` for the block; yield its base URL.

    Its output, with rewrite logging on, goes to log_path. Raises ValueError when the template
    no longer has the lines this adapts, RuntimeError when OpenResty rejects the configuration,
    exits, or does not listen within STARTUP_TIMEOUT_S.
    """
    prefix = tempfile.mkdtemp(prefix="hafah-rewriter-")
    try:
        os.makedirs(os.path.join(prefix, "conf"))
        os.makedirs(os.path.join(prefix, "logs"))
        port, health_port = free_port(), free_port()
        conf = os.path.join(prefix, "conf", "nginx.conf")
        with open(conf, "w") as out:
            out.write(_config(upstream, port, health_port))
        shutil.copy(_RULES, os.path.join(prefix, "conf", "rewrite_rules.conf"))
        command = [OPENRESTY, "-p", prefix, "-c", conf, "-e", "stderr", "-g", "daemon off;"]
        with open(log_path, "w") as log:
            if subprocess.run([*command, "-t"], stdout=log, stderr=subprocess.STDOUT, check=False).returncode != 0:
                raise RuntimeError(f"openresty rejects the rewriter's configuration; see {log_path}")
            log.flush()
            proc = subprocess.Popen(command, stdout=log, stderr=subprocess.STDOUT)
            try:
                deadline = time.monotonic() + STARTUP_TIMEOUT_S
                while not _listening(port):
                    if proc.poll() is not None:
                        raise RuntimeError(f"openresty exited with {proc.returncode}; see {log_path}")
                    if time.monotonic() > deadline:
                        raise RuntimeError(f"openresty not listening after {STARTUP_TIMEOUT_S}s; see {log_path}")
                    time.sleep(0.2)
                yield f"http://127.0.0.1:{port}"
            finally:
                proc.terminate()
                try:
                    proc.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    proc.kill()
    finally:
        shutil.rmtree(prefix, ignore_errors=True)
