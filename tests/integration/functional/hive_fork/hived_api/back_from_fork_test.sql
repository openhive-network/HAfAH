DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
-- GOT PREPARED DATA SCHEMA
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
    PERFORM hive.back_from_fork( 10 );
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
    ASSERT EXISTS ( SELECT FROM hive.events_queue WHERE event = 'BACK_FROM_FORK' AND block_num = 10 ), 'No event added';
    ASSERT ( SELECT COUNT(*) FROM hive.events_queue ) = 1, 'Unexpected number of events';
    ASSERT ( SELECT COUNT(*) FROM hive.fork WHERE id = 1 AND block_num = 10 ) = 1, 'No fork added';
    ASSERT ( SELECT COUNT(*) FROM hive.fork ) = 1, 'To much forks';
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
