import test_tools as tt
import time

from beekeepy.exceptions import ErrorInResponseError
from schemas.convert import to_builtins as _to_builtins
from schemas.fields.serializable import Serializable


def _enc_hook(obj):
    # schemas' field wrappers (HiveDateTime, assets, ...) know their own wire format
    if isinstance(obj, Serializable):
        return _to_builtins(obj.serialize(), enc_hook=_enc_hook)
    if isinstance(obj, int):
        return int(obj)
    return str(obj)


def to_plain(obj):
    """to_builtins with support for schemas' scalar/field wrappers (HiveInt etc.).

    Round-trips through JSON so containers normalize to their wire shapes
    (e.g. key_auths tuples become arrays)."""
    import json as _json

    return _json.loads(_json.dumps(_to_builtins(obj, enc_hook=_enc_hook)))


def send_request_to_hafah(hafah_node: tt.RemoteNode, method, **kwargs):
    previous_response = None
    for i in range(5):
        try:
            # Convert the typed msgspec response back to plain dicts/lists so the
            # tests can keep their JSON-shaped assertions.
            response = to_plain(getattr(hafah_node.api.account_history, method)(**kwargs))
        except ErrorInResponseError as error:
            if "Unknown Transaction" in error.error and i!=4:
                response = None
            else:
                raise
        if previous_response != response and previous_response is not None:
            return response
        previous_response = response
        time.sleep(1)
    return response


def get_hafah_irreversible_block(haf_node) -> int:
    """Last irreversible block in the HAF database, the upper bound of everything hafah serves."""
    return haf_node.query_one("SELECT hive.app_get_irreversible_block()")


def wait_for_irreversible_in_hafah(haf_node, block_number: int | None = None, *, timeout: float = 120) -> None:
    """Block until `block_number` (default: haf_node's current head block) is irreversible in the HAF database.

    The node's last irreversible block can run ahead of the database, so this waits on the value hafah reads.
    Raises TimeoutError when the block is not irreversible within `timeout` seconds."""
    target = block_number if block_number is not None else haf_node.get_last_block_number()
    tt.Time.wait_for(
        lambda: get_hafah_irreversible_block(haf_node) >= target,
        timeout=timeout,
        timeout_error_message=f"Waited too long for block {target} to become irreversible in the HAF database",
        poll_time=1.0,
    )
