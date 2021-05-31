DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
-- massive sync
INSERT INTO hive.blocks
VALUES
      ( 1, '\xBADD10', '\xCAFE10', '2016-06-22 19:10:21-07'::timestamp )
    , ( 2, '\xBADD20', '\xCAFE20', '2016-06-22 19:10:22-07'::timestamp )
    , ( 3, '\xBADD30', '\xCAFE30', '2016-06-22 19:10:23-07'::timestamp )
    , ( 4, '\xBADD40', '\xCAFE40', '2016-06-22 19:10:24-07'::timestamp )
    , ( 5, '\xBADD50', '\xCAFE50', '2016-06-22 19:10:25-07'::timestamp )
;
PERFORM hive.end_massive_sync();

-- live sync
PERFORM hive.push_block(
         ( 6, '\xBADD60', '\xCAFE60', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
         ( 7, '\xBADD70', '\xCAFE70', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.set_irreversible( 6 );

PERFORM hive.push_block(
         ( 8, '\xBADD80', '\xCAFE80', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
         ( 9, '\xBADD90', '\xCAFE90', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.back_from_fork( 7 );

PERFORM hive.push_block(
         ( 8, '\xBADD81', '\xCAFE81', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );

PERFORM hive.push_block(
         ( 9, '\xBADD91', '\xCAFE91', '2016-06-22 19:10:25-07'::timestamp )
        , NULL
        , NULL
        , NULL
    );
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
__blocks hive.blocks_range;
BEGIN
PERFORM hive.app_create_context( 'context' );
CREATE SCHEMA A;
CREATE TABLE A.table1(id  INTEGER ) INHERITS( hive.base );

SELECT * FROM hive.app_next_block( 'context' ) INTO __blocks; --block 1
ASSERT __blocks IS NOT NULL, 'Null is returned instead of range of blocks';
ASSERT __blocks.first_block = 1, 'Incorrect first block 1';
ASSERT __blocks.last_block = 5, 'Incorrect last range 5';
INSERT INTO A.table1 VALUES( 1 );

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
END
$BODY$
;

SELECT test_given();
SELECT test_when();
SELECT test_then();
