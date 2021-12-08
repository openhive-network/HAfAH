CREATE TABLE IF NOT EXISTS hive.blocks_reversible AS TABLE hive.blocks;
ALTER TABLE hive.blocks_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_hive_blocks_reversible PRIMARY KEY( num, fork_id ),
    ADD CONSTRAINT fk_1_hive_blocks_reversible FOREIGN KEY( fork_id ) REFERENCES hive.fork( id )
;

CREATE TABLE IF NOT EXISTS hive.transactions_reversible AS TABLE hive.transactions;
ALTER TABLE hive.transactions_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT fk_1_hive_transactions_reversible FOREIGN KEY (block_num, fork_id) REFERENCES hive.blocks_reversible(num,fork_id),
    ADD CONSTRAINT fk_2_hive_transactions_reversible FOREIGN KEY( fork_id ) REFERENCES hive.fork( id ),
    ADD CONSTRAINT uq_hive_transactions_reversible UNIQUE( trx_hash, fork_id )
;

CREATE INDEX IF NOT EXISTS hive_transactions_reversible_block_num_fork_id_idx ON hive.transactions_reversible( block_num, fork_id );

CREATE TABLE IF NOT EXISTS hive.transactions_multisig_reversible AS TABLE  hive.transactions_multisig;
ALTER TABLE hive.transactions_multisig_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_transactions_multisig_reversible PRIMARY KEY ( trx_hash, signature ),
    ADD CONSTRAINT fk_1_hive_transactions_multisig_reversible FOREIGN KEY (trx_hash, fork_id) REFERENCES hive.transactions_reversible(trx_hash, fork_id),
    ADD CONSTRAINT fk_2_transactions_multisig_reversible FOREIGN KEY( fork_id ) REFERENCES hive.fork( id )
;

CREATE TABLE IF NOT EXISTS hive.operations_reversible AS TABLE  hive.operations;
ALTER TABLE hive.operations_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_operations_reversible UNIQUE ( id, fork_id ),
    ADD CONSTRAINT fk_1_hive_operations_reversible FOREIGN KEY (block_num, fork_id) REFERENCES hive.blocks_reversible(num, fork_id),
    ADD CONSTRAINT fk_2_hive_operations_reversible FOREIGN KEY (op_type_id) REFERENCES hive.operation_types (id),
    ADD CONSTRAINT fk_3_hive_operations_reversible FOREIGN KEY ( fork_id ) REFERENCES hive.fork( id )
;

CREATE INDEX IF NOT EXISTS hive_operations_reversible_block_num_fork_id_idx ON hive.operations_reversible( block_num, fork_id );

CREATE TABLE IF NOT EXISTS hive.accounts_reversible AS TABLE hive.accounts;
ALTER TABLE hive.accounts_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT pk_hive_accounts_reversible_id UNIQUE( id, fork_id ),
    ADD CONSTRAINT fk_1_hive_accounts_reversible FOREIGN KEY ( block_num, fork_id ) REFERENCES hive.blocks_reversible( num, fork_id ),
    ADD CONSTRAINT fk_2_hive_accounts_reversible FOREIGN KEY ( fork_id ) REFERENCES hive.fork( id )
;

CREATE TABLE IF NOT EXISTS hive.account_operations_reversible AS TABLE hive.account_operations;
ALTER TABLE hive.account_operations_reversible
    ADD COLUMN IF NOT EXISTS fork_id BIGINT NOT NULL,
    ADD CONSTRAINT fk_1_hive_account_operations_reversible FOREIGN KEY ( operation_id, fork_id ) REFERENCES hive.operations_reversible( id, fork_id ),
    ADD CONSTRAINT fk_2_hive_account_operations_reversible FOREIGN KEY ( fork_id ) REFERENCES hive.fork( id )
;

CREATE INDEX IF NOT EXISTS hive_account_operations_reversible_operation_id_idx ON hive.account_operations_reversible(operation_id);