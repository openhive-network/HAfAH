DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE TYPE custom_type AS (
        id INTEGER,
        val FLOAT,
        name TEXT
        );

    CREATE TABLE src_table(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2) );
    INSERT INTO src_table ( smth, name, values, data, name2, num )
    VALUES( 1, 'temp1', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, '123abc')::custom_type, 'padu'::VARCHAR, 2.123::NUMERIC(3,2) );

    PERFORM hive_create_context( 'my_context' );
    PERFORM hive_register_table( 'src_table'::TEXT, 'my_context'::TEXT );
    PERFORM hive_context_next_block( 'my_context' );

    DELETE FROM src_table WHERE smth=1;
END;
$BODY$
;

DROP FUNCTION IF EXISTS test_when;
CREATE FUNCTION test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive_back_from_fork();
END
$BODY$
;

DROP FUNCTION IF EXISTS test_then;
CREATE FUNCTION test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM src_table WHERE name2='padu' ) = 1, 'Deleeted row was not reverted';
    ASSERT ( SELECT COUNT(*) FROM hive.hive_shadow_src_table ) = 0, 'Shadow table is not empty';
END
$BODY$
;


SELECT test_given();
SELECT test_when();
SELECT test_then();
