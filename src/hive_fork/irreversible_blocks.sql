CREATE TABLE IF NOT EXISTS hive.blocks (
       num integer NOT NULL,
       hash bytea NOT NULL,
       prev bytea NOT NULL,
       created_at timestamp without time zone NOT NULL,
       CONSTRAINT pk_hive_blocks PRIMARY KEY( num ),
       CONSTRAINT uq_hive_block UNIQUE( num )
);

CREATE TABLE IF NOT EXISTS hive.transactions (
    block_num integer NOT NULL,
    trx_in_block smallint NOT NULL,
    trx_hash bytea NOT NULL,
    ref_block_num integer NOT NULL,
    ref_block_prefix bigint NOT NULL,
    expiration timestamp without time zone NOT NULL,
    signature bytea DEFAULT NULL,
    CONSTRAINT pk_hive_transactions PRIMARY KEY ( trx_hash ),
    CONSTRAINT fk_1_hive_transactions FOREIGN KEY (block_num) REFERENCES hive.blocks (num)
);

CREATE TABLE IF NOT EXISTS hive.transactions_multisig (
    trx_hash bytea NOT NULL,
    signature bytea NOT NULL,
    CONSTRAINT pk_hive_transactions_multisig PRIMARY KEY ( trx_hash, signature ),
    CONSTRAINT fk_1_hive_transactions_multisig FOREIGN KEY (trx_hash) REFERENCES hive.transactions (trx_hash)
);

CREATE TABLE IF NOT EXISTS hive.operation_types (
    id smallint NOT NULL,
    name text NOT NULL,
    is_virtual boolean NOT NULL,
    CONSTRAINT pk_hive_operation_types PRIMARY KEY (id),
    CONSTRAINT uq_hive_operation_types UNIQUE (name)
);

CREATE TABLE IF NOT EXISTS hive.operations (
    id bigint not null,
    block_num integer NOT NULL,
    trx_in_block smallint NOT NULL,
    op_pos integer NOT NULL,
    op_type_id smallint NOT NULL,
    body text DEFAULT NULL,
    CONSTRAINT pk_hive_operations PRIMARY KEY ( id ),
    CONSTRAINT fk_1_hive_operations FOREIGN KEY (block_num) REFERENCES hive.blocks(num),
    CONSTRAINT fk_2_hive_operations FOREIGN KEY (op_type_id) REFERENCES hive.operation_types (id)
);

CREATE INDEX IF NOT EXISTS hive_transactions_block_num_trx_in_block_idx ON hive.transactions ( block_num, trx_in_block );
CREATE INDEX IF NOT EXISTS hive_operations_block_num_type_trx_in_block_idx ON hive.operations ( block_num, op_type_id, trx_in_block );
