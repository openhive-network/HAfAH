SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.get_ops_by_account(
    _account_id INT,
    _operations INT [],
    _from INT,
    _to INT,
    _body_limit INT,
    _offset INT,
    _limit INT
)
RETURNS SETOF hafah_backend.operation -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
AS
$$
BEGIN
  IF _operations IS NULL THEN
    RETURN QUERY
      SELECT * FROM hafah_backend.account_history_default(
        _account_id,
        _from,
        _to,
        _body_limit,
        _offset,
        _limit
    );
  END IF;

  RETURN QUERY
    SELECT * FROM hafah_backend.account_history_by_operations(
    _account_id,
    _operations,
    _from,
    _to,
    _body_limit,
    _offset,
    _limit
  );

END
$$;

RESET ROLE;
