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
    """to_builtins with support for schemas' scalar/field wrappers (HiveInt etc.)."""
    return _to_builtins(obj, enc_hook=_enc_hook)


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
