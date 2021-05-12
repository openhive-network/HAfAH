DROP FUNCTION IF EXISTS test_given;
CREATE FUNCTION test_given()
    RETURNS void
    LANGUAGE 'plpgsql'
VOLATILE
AS
$BODY$
BEGIN
    PERFORM hive.create_context( 'context' );
    CREATE TABLE table1(
          id INTEGER NOT NULL
        , smth TEXT NOT NULL
        , CONSTRAINT uq_table1 UNIQUE ( smth ) DEFERRABLE
    ) INHERITS( hive.base );

    PERFORM hive.context_next_block( 'context' );
    INSERT INTO table1( id, smth ) VALUES( 123, 'blabla1' );
    INSERT INTO table1( id, smth ) VALUES( 124, 'blabla2' );

    TRUNCATE hive.shadow_public_table1; --to do not revert inserts
    -- it is tricky, because DELETE operations are reverted before updates, then row wich violates the unique role will be inserted
    -- before the update which change the 'smth' to old name will solve the constraint violation
    DELETE FROM table1 WHERE id=123;
    UPDATE table1 SET smth='blabla1' WHERE id=124;
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
    -- because table1 will be first rewinded table2 will stay with incorrect FK for tabe1(id)
    PERFORM hive.back_context_from_fork(  'context'  );
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
    ASSERT ( SELECT COUNT(*) FROM table1 ) = 2, 'Deleted row was not reinserted';
    ASSERT EXISTS ( SELECT FROM table1 WHERE id=123 AND smth='blabla1' ), 'First row was not restored';
    ASSERT EXISTS ( SELECT FROM table1 WHERE id=124 AND smth='blabla2' ), 'Second row was not restored';
    ASSERT ( SELECT COUNT(*) FROM hive.shadow_public_table1 ) = 0, 'Shadow table is not empty';
END
$BODY$
;


SELECT test_given();
SELECT test_when();
SELECT test_then();
