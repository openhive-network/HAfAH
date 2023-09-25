from __future__ import annotations

import os
from pathlib import Path
import subprocess
from typing import TYPE_CHECKING, Callable, Final

import pytest

import test_tools as tt
from haf_local_tools import query_all, query_col

from shared_tools.complex_networks import create_block_log_directory_name

if TYPE_CHECKING:
    from sqlalchemy.engine.row import Row
    from sqlalchemy.engine.url import URL
    from sqlalchemy.orm.session import Session


DUMP_FILENAME: Final[str] = "adump.Fcsql"

SQL_ALL_TABLES_AND_VIEWS: Final[str] = """
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'hive' ORDER BY table_name;
"""

SQL_TABLE_COLUMNS: Final[str] = """
SELECT column_name 
FROM information_schema.columns  
WHERE table_schema = 'hive' AND table_name = :table;
"""

SQL_TABLE_CONTENT: Final[str] = """
SELECT * 
FROM hive.{table}
ORDER BY {columns};
"""

def pg_restore_from_toc(target_url: URL, tmp_path: Path) -> None:
    """
    For debugging purposes it is sometimes valuable to display dump contents like this:
    pg_restore --section=pre-data  --disable-triggers  -Fc -f adump-pre-data.sql  adump.Fcsql
    """
    dump_file_path = tmp_path / DUMP_FILENAME
    original_toc = tmp_path / 'original.toc'
    stripped_toc = tmp_path / 'stripped.toc'

    shell(f"pg_restore --clean --if-exists --exit-on-error -l {dump_file_path} > {original_toc}")

    shell(
        fr"grep -v '[0-9]\+; [0-9]\+ [0-9]\+ SCHEMA - hive'  {original_toc}" 
        fr"| grep -v '[0-9]\+; [0-9]\+ [0-9]\+ POLICY hive' > {stripped_toc}"
    )

    shell(
        f"pg_restore --clean --if-exists --exit-on-error --single-transaction -L {stripped_toc} -d {target_url} {dump_file_path}"
    )


def pg_restore_from_dump_file_only(target_url: URL, tmp_path: Path) -> None:
    dump_file_path = tmp_path / DUMP_FILENAME
    shell(f"pg_restore      --section=pre-data  --disable-triggers --clean --if-exists -d {target_url} {dump_file_path}")
    shell(f"pg_restore -j 3 --section=data      --disable-triggers --clean --if-exists -d {target_url} {dump_file_path}")
    shell(f"pg_restore      --section=post-data --disable-triggers --clean --if-exists -d {target_url} {dump_file_path}")


@pytest.mark.parametrize("pg_restore", [pg_restore_from_toc, pg_restore_from_dump_file_only])
def test_pg_dump(prepared_networks_and_database_1, database, pg_restore: Callable[[str, Path], None], tmp_path: Path):
    # GIVEN
    source_session, source_db_url = prepare_source_db(prepared_networks_and_database_1, database)
    target_session, target_db_url = prepare_target_db(database)
    source_database_not_empty_sanity_check(source_session)

    # WHEN
    pg_dump(source_db_url, tmp_path)
    pg_restore(target_db_url, tmp_path)

    # THEN
    compare_databases(source_session, target_session)
    compare_psql_tool_dumped_schemas(source_db_url, target_db_url, tmp_path)


def prepare_source_db(prepare_node, database) -> tuple[Session, URL]:
    node, session, db_url = prepare_node(database)
    node.run(replay_from=create_block_log_directory_name("block_log_12_8") / "block_log", stop_at_block=30, exit_before_synchronization=True)
    return session, db_url


def prepare_target_db(database) -> tuple[Session, URL]:
    DB_URL = os.getenv("DB_URL")
    session = database(f"{DB_URL}-test_pg_dump_target")
    db_url = session.bind.url
    return session, db_url


def pg_dump(url: URL, tmp_path: Path) -> None:
    shell(f'pg_dump -j 3 -Fd -d {url} -f {tmp_path / DUMP_FILENAME}')


def compare_databases(source_session: Session, target_session: Session) -> None:
    source_table_names = query_col(source_session, SQL_ALL_TABLES_AND_VIEWS)
    target_table_names = query_col(target_session, SQL_ALL_TABLES_AND_VIEWS)

    assert source_table_names == target_table_names

    for table in source_table_names:
        source_recordset = take_table_contents(source_session, table)
        target_recordset = take_table_contents(target_session, table)
        assert source_recordset == target_recordset, f"ERROR: in table_or_view: {table}"


def take_table_contents(session: Session, table: str) -> list[Row]:
    column_names = query_col(session, SQL_TABLE_COLUMNS, table=table)
    columns = ', '.join(column_names)
    sql_raw = SQL_TABLE_CONTENT.format(table=table, columns=columns)
    return query_all(session, sql_raw)


def compare_psql_tool_dumped_schemas(source_db_url: URL, target_db_url: URL, tmp_path: Path) -> None:
    source_schema = create_psql_tool_dumped_schema(source_db_url, tmp_path)
    target_schema = create_psql_tool_dumped_schema(target_db_url, tmp_path)

    assert source_schema == target_schema


def create_psql_tool_dumped_schema(db_url: URL, tmp_path: Path) -> str:
    schema_filename = tmp_path / (db_url.database + '_schema.txt')

    shell(rf"psql -d {db_url} -c '\dn'  > {schema_filename}")
    shell(rf"psql -d {db_url} -c '\d hive.*' >> {schema_filename}")

    with open(schema_filename, encoding="utf-8") as file:
        return file.read()


def shell(command: str) -> None:
    subprocess.check_call(command, shell=True)


def source_database_not_empty_sanity_check(source_session: Session):
    source_table_names = query_col(source_session, SQL_ALL_TABLES_AND_VIEWS)
    assert source_table_names, "No tables exist at all"
    account_operations_table_contents_exists = take_table_contents(source_session, 'blocks')
    assert account_operations_table_contents_exists, "Source table is empty, did we replay the blocklog?"

