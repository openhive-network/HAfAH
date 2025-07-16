SET ROLE hafah_owner;

CREATE OR REPLACE FUNCTION hafah_backend.get_ops_by_account(
    _account_id INT,
    _filter_account_ids INT [],
    _operations INT [],
    _from_block INT,
    _to_block INT,
    _page INT,
    _body_limit INT,
    _limit INT,
    _include_accounts BOOLEAN DEFAULT TRUE
)
RETURNS hafah_backend.account_operation_history -- noqa: LT01, CP05
LANGUAGE 'plpgsql' STABLE
AS
$$
DECLARE 
  _result hafah_backend.account_operation_history;

  -- flags
  _filter_by_op BOOLEAN:= (_operations IS NOT NULL);
  _filter_by_account BOOLEAN := (_filter_account_ids != ARRAY[NULL]::INT[]);
BEGIN
  CASE
    -- If no filters are applied, use the default account history function
    WHEN (NOT _filter_by_account) AND (NOT _filter_by_op) THEN
      _result := hafah_backend.account_history_default(
          _account_id,
          _from_block,
          _to_block,
          _page,
          _body_limit,
          _limit
      );
      
    -- If only operations are filtered, use the account history by operations function
    WHEN (NOT _filter_by_account) AND (_filter_by_op) THEN
      _result := hafah_backend.account_history_by_operations(
        _account_id,
        _operations,
        _from_block,
        _to_block,
        _page,
        _body_limit,
        _limit
      );
    -- If accounts are filtered, use the account history by accounts function (including accounts)
    WHEN (_filter_by_account) AND (_include_accounts) THEN
      _result := hafah_backend.account_history_including_accounts(
        _account_id,
        _operations,
        _filter_account_ids[1],
        _from_block,
        _to_block,
        _page,
        _body_limit,
        _limit
      );
    -- If accounts are filtered, use the account history by accounts function (excluding accounts)
    WHEN (_filter_by_account) AND (NOT _include_accounts) THEN
      _result := hafah_backend.account_history_excluding_accounts(
        _account_id,
        _operations,
        _filter_account_ids,
        _from_block,
        _to_block,
        _page,
        _body_limit,
        _limit
      );
    ELSE
      RAISE EXCEPTION 'Invalid parameters';
  END CASE;

  RETURN _result;
END
$$;

RESET ROLE;
