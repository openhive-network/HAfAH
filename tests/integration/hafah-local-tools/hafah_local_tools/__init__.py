import test_tools as tt
import time

def send_request_to_hafah(hafah_node: tt.RemoteNode, method, **kwargs):
    previous_response = None
    for _ in range(5):
        response = getattr(hafah_node.api.account_history, method)(**kwargs)
        if previous_response != response and previous_response is not None:
            return response
        previous_response = response
        time.sleep(1)
    return response
