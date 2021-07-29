DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    INSERT INTO hive.blocks
    VALUES
          ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
        , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:24-07'::timestamp )
    ;

    PERFORM hive.app_create_context( 'context' );
    CREATE SCHEMA A;
    CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.context );
    PERFORM hive.app_context_detach( 'context' );
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
    PERFORM hive.app_context_attach( 'context', 2 );
    INSERT INTO A.table1( id ) VALUES (10);
END;
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
    ASSERT EXISTS ( SELECT * FROM hive.contexts WHERE name='context' AND is_attached = TRUE ), 'Attach flag is still not set';

    ASSERT ( SELECT COUNT(*) FROM hive.shadow_a_table1 ) = 1, 'Trigger inserted something into shadow table1';
END;
$BODY$
;


