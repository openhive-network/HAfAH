﻿
CREATE OR REPLACE PROCEDURE haf_admin_test_given()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    PERFORM hive.context_create( 'context' );
    CREATE TABLE table1(
          id INTEGER NOT NULL
        , smth TEXT NOT NULL
        , CONSTRAINT uq_table1 UNIQUE ( smth )
    ) INHERITS( hive.context );

    PERFORM hive.context_next_block( 'context' );
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO table1( id, smth ) VALUES( 124, 'blabla2' );

    TRUNCATE hive.shadow_public_table1; --to do not revert inserts

    DELETE FROM table1 WHERE id=123;
    UPDATE table1 SET smth='blabla1' WHERE id=124;
END;
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_when()
LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    -- because table1 will be first rewinded table2 will stay with incorrect FK for tabe1(id)
    PERFORM hive.context_back_from_fork( 'context' , -1 );
END
$BODY$
;

CREATE OR REPLACE PROCEDURE haf_admin_test_then()
        LANGUAGE 'plpgsql'
AS
$BODY$
BEGIN
    ASSERT ( SELECT COUNT(*) FROM table1 ) = 2, 'Deleted row was not reinserted';
    ASSERT EXISTS ( SELECT FROM table1 WHERE id=123 AND smth='blabla1' ), 'First row was not restored';
    ASSERT EXISTS ( SELECT FROM table1 WHERE id=124 AND smth='blabla2' ), 'Second row was not restored';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 0, 'Shadow table is not empty';
END
$BODY$
;





