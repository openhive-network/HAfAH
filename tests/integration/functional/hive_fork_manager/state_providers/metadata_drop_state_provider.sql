DROP FUNCTION IF EXISTS haf_admin_test_given;
CREATE FUNCTION haf_admin_test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.app_create_context( 'context' );
END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_when;
CREATE FUNCTION haf_admin_test_when()
    RETURNS void
    LANGUAGE 'plpgsql'
    VOLATILE
AS
$BODY$
DECLARE
    __tables TEXT[];
BEGIN
    SELECT hive.start_provider_metadata( 'context' ) INTO __tables;

    ASSERT ( __tables = ARRAY[ 'context_metadata' ]::TEXT[] ), 'Wrong table name';

    PERFORM hive.drop_state_provider_metadata( 'context' );

END;
$BODY$
;

DROP FUNCTION IF EXISTS haf_admin_test_then;
CREATE FUNCTION haf_admin_test_then()
    RETURNS void
    LANGUAGE 'plpgsql'
STABLE
AS
$BODY$
BEGIN
    ASSERT NOT EXISTS ( SELECT FROM information_schema.tables WHERE table_schema='hive' AND table_name  = 'context_metadata' ), 'Metadata table was not dropped';
END;
$BODY$
;