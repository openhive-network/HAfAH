DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.create_context( 'my_context' );
    PERFORM hive.create_context( 'my_context2' );
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
DECLARE
    __block1 INTEGER := -1;
    __block2 INTEGER := -1;
BEGIN
    SELECT  hive_context_next_block( 'my_context' ) INTO __block1;
    PERFORM hive_context_next_block( 'my_context2' );
    SELECT hive_context_next_block( 'my_context2' ) INTO __block2;

    ASSERT __block1 = 0;
    ASSERT __block2 = 1;
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
    ASSERT EXISTS ( SELECT FROM hive.context WHERE name = 'my_context' AND current_block_num = 0 );
    ASSERT EXISTS ( SELECT FROM hive.context WHERE name = 'my_context2' AND current_block_num = 1 );
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
