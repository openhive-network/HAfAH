CREATE OR REPLACE FUNCTION hive.start_provider_accounts( _context hive.context_name )
    RETURNS TEXT[]
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_accounts';
BEGIN
    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
    INTO __context_id;

    IF __context_id IS NULL THEN
         RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'CREATE TABLE hive.%I(
                      id SERIAL
                    , name TEXT
                    , CONSTRAINT pk_%s PRIMARY KEY( id )
                    )', __table_name, __table_name
    );

    RETURN ARRAY[ __table_name ];
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_account_from_pow( _pow_operation TEXT )
    RETURNS TEXT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN json_extract_path_text( CAST( _pow_operation as json ), 'worker_account' );
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_account_from_pow2( _pow2_operation TEXT )
    RETURNS TEXT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
DECLARE
    __result TEXT;
BEGIN
    SELECT json_extract_path_text( work_arrays.work[2], 'input', 'worker_account' )
    INTO __result
    FROM (
        SELECT array_agg( work.* ) as work
        FROM json_array_elements( json_extract_path( CAST( _pow2_operation as json ), 'work' ) ) as work
        ) as work_arrays
    ;

    RETURN __result;
END;
$BODY$
;

CREATE OR REPLACE FUNCTION hive.get_account_from_accounts_operations( _account_operation TEXT )
    RETURNS TEXT
    LANGUAGE plpgsql
    IMMUTABLE
AS
$BODY$
BEGIN
    RETURN json_extract_path_text( CAST( _account_operation as json ), 'new_account_name' );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.update_state_provider_accounts( _first_block hive.blocks.num%TYPE, _last_block hive.blocks.num%TYPE, _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_accounts';
BEGIN
    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
        INTO __context_id;

    IF __context_id IS NULL THEN
             RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format(
        'INSERT INTO hive.%s_accounts( name )
        SELECT CASE lower( ot.name )
            WHEN ''hive::protocol::pow_operation'' THEN hive.get_account_from_pow( ov.body )
            WHEN ''hive::protocol::pow2_operation'' THEN hive.get_account_from_pow2( ov.body )
            ELSE hive.get_account_from_accounts_operations( ov.body )
        END as name
        FROM hive.%s_operations_view ov
        JOIN hive.operation_types ot ON ov.op_type_id = ot.id
        WHERE
            ARRAY[ lower( ot.name ) ] <@ ARRAY[ ''hive::protocol::pow_operation'', ''hive::protocol::pow2_operation'', ''hive::protocol::account_create_operation'', ''hive::protocol::create_claimed_account_operation'', ''hive::protocol::account_create_with_delegation_operation'' ]
            AND ov.block_num BETWEEN %s AND %s
        ON CONFLICT DO NOTHING'
        , _context, _context, _first_block, _last_block
    );
END;
$BODY$
;


CREATE OR REPLACE FUNCTION hive.drop_state_provider_accounts( _context hive.context_name )
    RETURNS void
    LANGUAGE plpgsql
    VOLATILE
AS
$BODY$
DECLARE
    __context_id hive.contexts.id%TYPE;
    __table_name TEXT := _context || '_accounts';
BEGIN
    SELECT hac.id
    FROM hive.contexts hac
    WHERE hac.name = _context
    INTO __context_id;

    IF __context_id IS NULL THEN
        RAISE EXCEPTION 'No context with name %', _context;
    END IF;

    EXECUTE format( 'DROP TABLE hive.%I', __table_name );
END;
$BODY$
;
