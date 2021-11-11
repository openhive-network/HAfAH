DROP SCHEMA IF EXISTS btracker CASCADE;

CREATE SCHEMA btracker;

CREATE TABLE IF NOT EXISTS btracker.current_account_balances
(
  account VARCHAR NOT NULL, -- Balance owner account
  nai     INT NOT NULL,     -- Balance type (currency)
  balance BIGINT NOT NULL,  -- Balance value (amount of held tokens)
  source_op BIGINT NOT NULL,-- The operation triggered last balance change
  source_op_block INT NOT NULL, -- Block containing the source operation

  CONSTRAINT pk_current_account_balances PRIMARY KEY (account, nai)
);

--- Helper view, just to perform INSTEAD OF INSERT actions and record balance changes.
CREATE OR REPLACE VIEW btracker.account_balances_view
AS
SELECT account, nai, source_op, source_op_block, balance
FROM btracker.current_account_balances
;

CREATE TABLE IF NOT EXISTS btracker.account_balance_history
(
  account VARCHAR NOT NULL, -- Balance owner account
  nai     INT NOT NULL,     -- Balance type (currency)
  balance BIGINT NOT NULL,  -- Balance value after a change
  source_op BIGINT NOT NULL,-- The operation triggered given balance change
  source_op_block INT NOT NULL, -- Block containing the source operation
  
  /** Because of bugs in blockchain at very begin, it was possible to make a transfer to self. See summon transfer in block 118570
      That's why constraint has been extended - originally it was planned to cover only account, nai, source_op
  */
  CONSTRAINT pk_account_balance_history PRIMARY KEY (account, source_op_block, nai, source_op, balance)
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
  (account, nai, source_op, source_op_block, balance)
  SELECT NEW.account, NEW.nai, NEW.source_op, NEW.source_op_block, NEW.balance
  ;
  END IF;
  
  INSERT INTO btracker.account_balance_history
  (account, nai, source_op, source_op_block, balance)
  SELECT NEW.account, NEW.nai, NEW.source_op, NEW.source_op_block, NEW.balance + COALESCE(__current_balance, 0)
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
WITH balance_impacting_ops AS
(
  SELECT ot.id
  FROM hive.operation_types ot
  WHERE ot.name IN (SELECT * FROM hive.get_balance_impacting_operations())
)
INSERT INTO btracker.account_balances_view
(account, nai, balance, source_op, source_op_block)
SELECT bio.account_name AS account, bio.asset_symbol_nai AS nai, bio.amount, ho.id AS source_op, ho.block_num
FROM hive.operations ho
JOIN balance_impacting_ops b ON ho.op_type_id = b.id
JOIN LATERAL
(
  SELECT * FROM hive.get_impacted_balances(ho.body)
) bio ON true
WHERE ho.block_num BETWEEN _from AND _to
ORDER BY ho.block_num, ho.id
;
END
$$
;
