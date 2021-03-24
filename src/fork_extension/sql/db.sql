DROP TYPE IF EXISTS custom_type CASCADE;
CREATE TYPE custom_type AS (
	id INTEGER,
	val FLOAT,
	name TEXT
);

DROP TABLE IF EXISTS blocks;
CREATE TABLE blocks(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2) );

DROP TABLE IF EXISTS blocks_copy;
CREATE TABLE blocks_copy(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type, name2 VARCHAR, num NUMERIC(3,2) );

--CREATE TABLE blocks(id INTEGER);

DROP TABLE IF EXISTS tuples;
CREATE TABLE tuples(id integer, table_name text, tuple_prev bytea, tuple_old bytea);


DROP FUNCTION IF EXISTS table_changed_service CASCADE;
CREATE FUNCTION table_changed_service() RETURNS trigger
AS '/home/syncad/src/psql_tools/cmake-build-release/fork_extension/libfork_extension.so'
LANGUAGE C;

DROP FUNCTION IF EXISTS back_from_fork CASCADE;
CREATE FUNCTION back_from_fork() RETURNS void
AS '/home/syncad/src/psql_tools/cmake-build-release/fork_extension/libfork_extension.so', 'back_from_fork'
LANGUAGE C;


CREATE TRIGGER tbefore AFTER INSERT ON blocks
    REFERENCING NEW TABLE AS new_table
    FOR EACH STATEMENT EXECUTE PROCEDURE table_changed_service();




-- WHEN something is inserted to blocks than tuples are inserted to tuples
--INSERT INTO blocks VALUES( '{{159, 273, 33333 }}' ); --ARRAY
--INSERT INTO blocks VALUES( ROW(1, 5.8, 'dupa') ); --CUSTOM TYPE
--INSERT INTO blocks ( smth, name, values, data ) VALUES( 1, 'dupa', '{{0.25, 3.4, 6}}', ROW(1, 5.8, 'zbita') ); 

-- TESTY PERFORMANCOWE NA TABLICY: CREATE TABLE blocks(id INTEGER);
--Przed każdym testem puszczone DROPy wszystkich tablic , funkcji i triggerów, potem tworzine na nowo
-- nie stwierdzono znaczacej różnicy miedzy buildami DEBUG i RELEASE
-- UWAGA: bardzo wolne jest tworzenie pq_connection, czas średni per row: 5ms; z zachowanym connection: 60us (44us sam start copy + 5us serializacja(pesymistycznie) + 11us wkopiowanie(pesymistycznie) )  
INSERT INTO blocks SELECT gen.id FROM generate_series(1, 1000000) AS gen(id) ; --NO TRIGGER(464ms,456ms,477ms), TRIGGER(>2m30s)
INSERT INTO blocks SELECT gen.id FROM generate_series(1, 100) AS gen(id) ; --NO TRIGGER(12ms,11ms,11ms ), TRIGGER_PQ_RECCONECT(494ms,454ms,464ms), TRIGGER(21ms,11ms,21ms)
INSERT INTO blocks SELECT gen.id FROM generate_series(1, 1000) AS gen(id) ;
	--NO TRIGGER(11ms,11ms,11ms)
	--TRIGGER(4.5s,4.5s,4.5s),
		--NO SERIALIZE(4.5s)
		--NO COPY AT ALL(4.2s, 4.2s, 4.2s) //NO DIFFERENCES BETWEEN DEBUG/RELEASE
		--NO PQCONNECTION(11ms)
		--GLOBAL PQCONNECTION ( 11ms, 15ms,11ms )
INSERT INTO blocks SELECT gen.id FROM generate_series(1, 10000) AS gen(id) ;
	--NO TRIGGER(11ms,12ms,11ms),
	--TRIGGER_PQ_RECCONECT(45s,45s,45s),
	--TRIGGER(615ms,564ms,585ms),
	--TRIGGER_NO_COPY(21ms,21ms,21ms),
	--ONLY_COPY_INIT_NO_PUSH(454ms,433ms, 443ms)
	--NO_SERIALIZATION(524ms, 535ms, 605ms )
INSERT INTO blocks SELECT gen.id FROM generate_series(1, 100000) AS gen(id) ; --NO TRIGGER(61ms,51ms,52ms), TRIGGER_PQ_RECCONECT(7m34s=453s), TRIGGER(5.8s, 4.8s, 5.1s),


CREATE TABLE blocks2(id  SERIAL PRIMARY KEY, smth INTEGER, name TEXT, values FLOAT[], data custom_type);


INSERT INTO blocks ( smth, name, values, data, name2, num ) 
SELECT gen.id, val.name, val.arr, val.rec, val.name2, val.num
FROM generate_series(1, 10000) AS gen(id)
JOIN ( VALUES( 'dupa', '{{0.25, 3.4, 6}}'::FLOAT[], ROW(1, 5.8, 'zbita')::custom_type, 'dupa2'::VARCHAR, 2.123::NUMERIC(3,2) ) ) as val(name,arr,rec, name2, num) ON True;--val.id = gen.id
--NO TRIGGER 31ms,31ms,41ms
--TRIGGER( 81ms, 81ms, 91ms   )

SELECT back_from_fork();

SELECT * FROM blocks;
SELECT * FROM blocks_copy; // 10000: 
SELECT * FROM tuples LIMIT 100;

SELECT * FROM pg_type;

DROP TABLE ints;
CREATE TABLE ints( id INTEGER);
INSERT INTO ints SELECT gen.id
FROM generate_series(1, 1000000) AS gen(id) ;

SELECT * FROM ints LIMIT 100

--SELECT *
--  FROM generate_series(1, 1000)


-- SELECT * FROM blocks;
-- SELECT * FROM trig;
-- TRUNCATE blocks;
-- LOAD '/home/syncad/src/postgres_forks/hive/cmake-build-debug/programs/second_layer/libsecond_layer.so'

SELECT * FROM blocks2;

drop table if exists blocks2;
create table blocks2(id INTEGER);

--DROP FUNCTION IF EXISTS sql_trigger CASCADE;
--CREATE OR REPLACE FUNCTION sql_trigger()
--RETURNS TRIGGER
--AS $trigger$
--   BEGIN
--        IF (TG_OP = 'INSERT') THEN
--            INSERT INTO blocks2 SELECT n.* FROM new_table n;
--        END IF;
--        RETURN NULL;
--    END;
--$trigger$
--LANGUAGE plpgsql;

--CREATE TRIGGER blocks_ins
--    AFTER INSERT ON blocks
--    REFERENCING NEW TABLE AS new_table
--    FOR EACH STATEMENT EXECUTE PROCEDURE sql_trigger();


DROP FUNCTION IF EXISTS sql_trigger_row CASCADE;
CREATE OR REPLACE FUNCTION sql_trigger_row()
RETURNS TRIGGER
AS $trigger$
    BEGIN
        IF (TG_OP = 'INSERT') THEN
            INSERT INTO blocks2 VALUES( NEW.id );
        END IF;
        RETURN NULL;
    END;
$trigger$
LANGUAGE plpgsql;




CREATE TRIGGER blocks_ins_row
    AFTER INSERT ON blocks
    FOR EACH ROW EXECUTE PROCEDURE sql_trigger_row();

SELECT current_database();

SELECT *
FROM pg_settings
WHERE name = 'port';

SELECT *
FROM pg_settings;



    
