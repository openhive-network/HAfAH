--TODO set names tested and reference schemas; set schema, where you want to have a function and set owner 
--Author: rmaslowski
--Taken from branch: https://gitlab.syncad.com/hive/hivemind/-/blob/rm-database-tests/scripts/tests/tests_hafah/join_test_account_operations

DROP FUNCTION if exists public.join_test_account_operations();

CREATE OR REPLACE FUNCTION public.join_test_account_operations(
  )
    RETURNS TABLE(
    hive_rowid_t bigint,
    account_id_t int,
    account_op_seq_no_t int,
    operation_id_t bigint,
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
            ao.hive_rowid, ao.account_id, ao.account_op_seq_no, ao.operation_id, '2' as note
      from 
        hafah.account_operations as ao inner join hafah_python.account_operations as aoc
      on ao.account_id = aoc.account_id and ao.operation_id = aoc.operation_id
      where 
        ao.account_op_seq_no<>aoc.account_op_seq_no
       )

      union all

      (select 
        *, '-1' as note
        from 
        hafah.account_operations as ao
       WHERE not EXISTS (
        select * from hafah_python.account_operations as aoc where ao.account_id = aoc.account_id and ao.operation_id = aoc.operation_id)
      )

      union all

      (select 
        *, '+1' as note
        from 
        hafah_python.account_operations as aoc
       WHERE not EXISTS (
        select * from hafah.account_operations ao where ao.account_id = aoc.account_id and ao.operation_id = aoc.operation_id)
      )
  )as x order by note ;

end;
$BODY$;
