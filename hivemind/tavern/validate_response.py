def validate_response(response):
  """ Make sure that there is no error field in response json and there is a result field in response"""
  error = response.json().get("error", None)
  result = response.json().get("result", None)
  assert error is None, "Error detected in response: {}".format(error["message"])
  assert result is not None, "Error detected in response: no result"