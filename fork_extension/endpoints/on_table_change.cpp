#include "include/exceptions.hpp"
#include "include/relation.hpp"
#include "include/postgres_includes.hpp"
#include "include/pq/db_client.hpp"
#include "include/pq/copy_to_reversible_tuples_session.hpp"

#include "gen/git_version.hpp"

#include <cassert>
#include <mutex>
#include <string>
#include <include/relation.hpp>

using ForkExtension::PostgresPQ::DbClient;

extern "C" {
PG_FUNCTION_INFO_V1(on_table_change);
}

Datum on_table_change(PG_FUNCTION_ARGS) try {
  LOG_WARNING( "trigger" );

  if (!CALLED_AS_TRIGGER(fcinfo)) {
    LOG_ERROR( "table_changed_service: not called by trigger manager" );
    return 0;
  }

  TriggerData* trig_data = reinterpret_cast<TriggerData*>( fcinfo->context );

  if ( !TRIGGER_FIRED_FOR_STATEMENT(trig_data->tg_event) ) {
    LOG_WARNING("table_changed_service: not supported statement trigger");
    return 0;
  }

  if ( TRIGGER_FIRED_BY_DELETE(trig_data->tg_event) ) {
    assert( trig_data );
    assert( trig_data->tg_oldtable );

    ForkExtension::PostgresPQ::DbClient::currentDatabase();

    auto copy_session = DbClient::currentDatabase().startCopyToReversibleTuplesSession();
    TupleDesc tup_desc = trig_data->tg_relation->rd_att;

    if ( trig_data->tg_oldtable == nullptr ) {
      THROW_RUNTIME_ERROR( "No trigger tuple for delete" );
    }

    auto slot = MakeTupleTableSlot();

    const std::string trigg_table_name = SPI_getrelname(trig_data->tg_relation);
    tuplestore_rescan( trig_data->tg_oldtable );
    while ( tuplestore_gettupleslot( trig_data->tg_oldtable, true, false, slot ) ) {
      if ( !slot->tts_tuple ) {
        THROW_RUNTIME_ERROR( "Virtual tuples are not supported" );
      }
      copy_session->push_delete(trigg_table_name, *slot->tts_tuple, tup_desc);
    } // while next tuple
    return 0;
  }

  if ( TRIGGER_FIRED_BY_UPDATE(trig_data->tg_event) ) {
    LOG_WARNING("Table update not supported");
    return 0;
  }

  if ( TRIGGER_FIRED_BY_INSERT(trig_data->tg_event) ) {
    LOG_WARNING("Insert not supported");
    return 0;
  }


  return 0;
}
catch ( std::exception& _exception ) {
  LOG_ERROR( "Unhandled exception: %s", _exception.what() );
  return 0;
}
catch( ... ) {
  LOG_ERROR( "Unhandled unknown exception" );
  return 0;
}

