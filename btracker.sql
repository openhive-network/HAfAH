CREATE SCHEMA IF NOT EXISTS btracker;

CREATE TABLE IF NOT EXISTS btracker.current_account_balances
(
  account VARCHAR NOT NULL, -- Balance owner account
  nai     INT NOT NULL,     -- Balance type (currency)
  balance BIGINT NOT NULL,  -- Balance value (amount of held tokens)
  source_op BIGINT NOT NULL,-- The operation triggered last balance change
  CONSTRAINT pk_current_account_balances PRIMARY KEY (account, nai)
);

--- Helper view, just to perform INSTEAD OF INSERT actions and record balance changes.
CREATE OR REPLACE VIEW btracker.account_balances_view
AS
SELECT account, nai, source_op, balance
FROM btracker.current_account_balances
;

CREATE TABLE IF NOT EXISTS btracker.account_balance_history
(
  account VARCHAR NOT NULL, -- Balance owner account
  nai     INT NOT NULL,     -- Balance type (currency)
  balance BIGINT NOT NULL,  -- Balance value after a change
  source_op BIGINT NOT NULL,-- The operation triggered given balance change
  
  CONSTRAINT pk_account_balance_history PRIMARY KEY (account, nai, source_op)
);

CREATE OR REPLACE FUNCTION btracker.on_account_balances_view_insert()
    RETURNS TRIGGER
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE NOT LEAKPROOF
AS $BODY$
DECLARE
  __current_balance btracker.current_account_balances.balance%TYPE;
BEGIN
  SELECT cab.balance INTO __current_balance
  FROM btracker.current_account_balances cab
  WHERE cab.account = NEW.account AND cab.nai = NEW.nai;
  
  IF __current_balance IS NOT NULL THEN
    UPDATE btracker.current_account_balances cab
  SET balance = __current_balance + NEW.balance,
      source_op = NEW.source_op
  WHERE cab.account = NEW.account AND cab.nai = NEW.nai;
  ELSE
    INSERT INTO btracker.current_account_balances
  (account, nai, source_op, balance)
  SELECT NEW.account, NEW.nai, NEW.source_op, NEW.balance
  ;
  END IF;
  
  INSERT INTO btracker.account_balance_history
  (account, nai, source_op, balance)
  SELECT NEW.account, NEW.nai, NEW.source_op, NEW.balance + COALESCE(__current_balance, 0)
  ;
  RETURN NEW;
END;
$BODY$;

DROP TRIGGER IF EXISTS btracker_instead_of_insert ON btracker.account_balances_view;
CREATE TRIGGER btracker_instead_of_insert
INSTEAD OF INSERT ON btracker.account_balances_view
FOR EACH ROW
EXECUTE FUNCTION btracker.on_account_balances_view_insert();


CREATE OR REPLACE FUNCTION btracker.process_block_range_data(in _from INT, in _to INT)
RETURNS VOID
LANGUAGE 'plpgsql'
AS
$$
BEGIN
INSERT INTO btracker.account_balances_view
(account, nai, balance, source_op)
select bio.account_name as account, bio.asset_symbol_nai as nai, bio.amount, ho.id as source_op
from hive.operations ho
join lateral
(
  SELECT * FROM hive.get_impacted_balances(ho.body)
) bio ON true
WHERE ho.block_num BETWEEN _from AND _to
ORDER BY ho.block_num, ho.id
;
END
$$
;
