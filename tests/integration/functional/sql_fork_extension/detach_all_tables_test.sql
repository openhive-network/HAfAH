DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    CREATE SCHEMA A;
    CREATE SCHEMA B;
    PERFORM hive.create_context( 'context' );
    CREATE TABLE A.table1(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( hive.base );
    CREATE TABLE B.table2(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( hive.base );
    PERFORM hive.create_context( 'context2' );
    CREATE TABLE A.table3(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT) INHERITS( hive.base );
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
    PERFORM hive.detach_all( 'context' );
    PERFORM hive_context_next_block( 'context' );
    PERFORM hive_context_next_block( 'context2' );
    INSERT INTO A.table1( smth, name ) VALUES (1, 'abc' );
    INSERT INTO B.table2( smth, name ) VALUES (1, 'abc' );
    INSERT INTO A.table3( smth, name ) VALUES (1, 'abc' );
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
    ASSERT EXISTS ( SELECT * FROM hive.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table1' AND is_attached = FALSE ), 'Attach flag is not set to false';
    ASSERT NOT EXISTS ( SELECT * FROM hive.shadow_a_table1 ), 'Trigger iserted something into shadow table';

    ASSERT EXISTS ( SELECT * FROM hive.registered_tables WHERE origin_table_schema='b' AND origin_table_name='table2' AND is_attached = FALSE ), 'Attach flag is not set to false';
    ASSERT NOT EXISTS ( SELECT * FROM hive.shadow_b_table2 ), 'Trigger iserted something into shadow table';

    ASSERT EXISTS ( SELECT * FROM hive.registered_tables WHERE origin_table_schema='a' AND origin_table_name='table3' AND is_attached = TRUE ), 'Attach flag is not set to true';
    ASSERT EXISTS ( SELECT * FROM hive.shadow_a_table3 ), 'Trigger did not iserte something into shadow table';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
