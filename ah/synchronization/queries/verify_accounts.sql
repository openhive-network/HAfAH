--TODO set names tested and reference schemas; set schema, where you want to have a function and set owner 
--Author: rmaslowski
--Taken from branch: https://gitlab.syncad.com/hive/hivemind/-/blob/rm-database-tests/scripts/tests/tests_hafah/join_test_accounts

DROP FUNCTION if exists public.join_test_accounts();

CREATE OR REPLACE FUNCTION public.join_test_accounts(
  )
    RETURNS TABLE(
    hive_rowid_t bigint,
    id_t int,
    name_t character varying,
    add_delete_modif text

  ) 
    LANGUAGE 'plpgsql'
    COST 100
    VOLATILE PARALLEL UNSAFE
    ROWS 1000

AS $BODY$
DECLARE
begin

  return query 
  select * from(
      (select 
            ao.hive_rowid, ao.id, ao.name, '2' as note
      from 
        hafah_python.accounts as ao inner join hafah.accounts as aoc
      on ao.id = aoc.id
      where 
        ao.name<>aoc.name
       )

      union all

      (select 
        *, '-1' as note
        from 
        hafah_python.accounts as ao
       WHERE not EXISTS (
        select * from hafah.accounts as aoc where ao.id = aoc.id)
      )

      union all

      (select 
        *, '+1' as note
        from 
        hafah.accounts as aoc
       WHERE not EXISTS (
        select * from hafah_python.accounts ao where ao.id = aoc.id)
      )
  )as x order by note ;

end;
$BODY$;

ALTER FUNCTION public.join_test_accounts()
    OWNER TO dev;