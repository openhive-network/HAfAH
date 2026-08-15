import test_tools as tt
import time

from beekeepy.exceptions import ErrorInResponseError
from schemas.convert import to_builtins


def send_request_to_hafah(hafah_node: tt.RemoteNode, method, **kwargs):
    previous_response = None
    for i in range(5):
        try:
            # Convert the typed msgspec response back to plain dicts/lists so the
            # tests can keep their JSON-shaped assertions.
            response = to_builtins(getattr(hafah_node.api.account_history, method)(**kwargs))
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
