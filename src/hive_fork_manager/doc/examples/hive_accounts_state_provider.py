#!/usr/bin/env python3

import sys
import sqlalchemy

APPLICATION_CONTEXT = "accounts_ctx"
SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE = """
    CREATE TABLE IF NOT EXISTS public.trx_histogram(
          day DATE
        , trx INT
        , CONSTRAINT pk_trx_histogram PRIMARY KEY( day ) )
    INHERITS( hive.{} )
    """.format( APPLICATION_CONTEXT )

def create_db_engine(db_name, pg_port):
    return sqlalchemy.create_engine(
                "postgresql://alice:test@localhost:{}/{}".format(pg_port, db_name), # this is only example of db
                isolation_level="READ COMMITTED",
                pool_size=1,
                pool_recycle=3600,
                echo=False)

def prepare_application_data( db_connection ):
        # create a new context only if it not already exists
        exist = db_connection.execute( "SELECT hive.app_context_exists( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone();
        if exist[ 0 ] == False:
            db_connection.execute( "SELECT hive.app_create_context( '{}', TRUE )".format( APPLICATION_CONTEXT ) )

        # create and register a table
        db_connection.execute( SQL_CREATE_AND_REGISTER_HISTOGRAM_TABLE )

        # import accounts state provider
        db_connection.execute( "SELECT hive.app_state_provider_import( 'ACCOUNTS', '{}' )".format( APPLICATION_CONTEXT ) );

def main_loop( db_connection ):
    # forever loop
    while True:
        # start a new transaction
        with db_connection.begin():
            # get blocks range
            blocks_range = db_connection.execute( "SELECT * FROM hive.app_next_block( '{}' )".format( APPLICATION_CONTEXT ) ).fetchone()
            accounts = db_connection.execute( "SELECT * FROM hive.{}_accounts ORDER BY id DESC LIMIT 1".format( APPLICATION_CONTEXT ) ).fetchall()

            print( "Blocks range {}".format( blocks_range ) )
            print( "Accounts {}".format( accounts ) )
            (first_block, last_block) = blocks_range;
            # if no blocks are fetched then ask for new blocks again
            if not first_block:
                continue;

            (first_block, last_block) = blocks_range;

            # check if massive sync is required
            if ( last_block - first_block ) > 100:
                # Yes, massive sync is required
                # detach context
                db_connection.execute( "SELECT hive.app_context_detach( '{}' )".format( APPLICATION_CONTEXT ) )

                # update massivly the application's table - one commit transaction for whole massive edition
                db_connection.execute( "SELECT hive.app_state_providers_update( {}, {}, '{}' )".format( first_block, last_block, APPLICATION_CONTEXT ) )

                # attach context and moves it to last synced block
                db_connection.execute( "SELECT hive.app_context_attach( '{}', {} )".format( APPLICATION_CONTEXT, last_block ) )
                continue

            # process the first block in range - one commit after each block
            db_connection.execute( "SELECT hive.app_state_providers_update( {}, {}, '{}' )".format( first_block, first_block, APPLICATION_CONTEXT ) )

def start_application(db_name, pg_port):
    engine = create_db_engine(db_name, pg_port)
    with engine.connect() as db_connection:
        prepare_application_data( db_connection )
        main_loop( db_connection )

if __name__ == '__main__':
    try:
        db_name = sys.argv[1] if (len(sys.argv) > 1) else 'psql_tools_test_db'
        pg_port = sys.argv[2] if (len(sys.argv) > 2) else 5432
        start_application(db_name, pg_port)
    except KeyboardInterrupt:
        print( "Break by the user request" )
        pass
