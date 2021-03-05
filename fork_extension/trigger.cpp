#include "include/trigger.h"

#include "include/postgres_includes.hpp"
#include "include/pq/db_client.hpp"
#include "include/pq/copy_to_reversible_tuples_session.hpp"

#include <cassert>
#include <mutex>
#include <string>

using SecondLayer::PostgresPQ::DbClient;

Datum table_changed_service(PG_FUNCTION_ARGS) try {

  elog(WARNING, "trigger");

  if (!CALLED_AS_TRIGGER(fcinfo)) {
    elog(ERROR, "table_changed_service: not called by trigger manager");
    return 0;
  }

  TriggerData* trig_data = reinterpret_cast<TriggerData*>( fcinfo->context );

  if ( !TRIGGER_FIRED_FOR_STATEMENT(trig_data->tg_event) ) {
    elog(WARNING, "table_changed_service: not supported statement trigger");
    return 0;
  }

  if ( TRIGGER_FIRED_BY_INSERT(trig_data->tg_event) ) {
    assert( trig_data );
    assert( trig_data->tg_trigtuple );
    // only configuration can deliver db, check if we can use postgres config
    // TODO: check if connection is still valid
    SecondLayer::PostgresPQ::DbClient::get();

    auto copy_session = DbClient::get().startCopyToReversibleTuplesSession();
    TupleDesc tup_desc = trig_data->tg_relation->rd_att;

    if ( trig_data->tg_newtable == nullptr ) {
      throw std::runtime_error( "No trigger tuple for insert" );
    }

    auto slot = MakeTupleTableSlot();

    tuplestore_rescan( trig_data->tg_newtable );
    while ( tuplestore_gettupleslot( trig_data->tg_newtable, true, false, slot ) ) {
      if ( !slot->tts_tuple ) {
        throw std::runtime_error( "Virtual tuples are not supported" );
      }
      copy_session->push_insert(SPI_getrelname(trig_data->tg_relation), *slot->tts_tuple, tup_desc);
    } // while next tuple
    return 0;
  }

  if ( TRIGGER_FIRED_BY_UPDATE(trig_data->tg_event) ) {
    return 0;
  }

  if ( TRIGGER_FIRED_BY_DELETE(trig_data->tg_event) ) {
    return 0;
  }


  return 0;
}
catch ( std::exception& _exception ) {
  ereport(
    ERROR,
    (errcode(ERRCODE_TRIGGERED_ACTION_EXCEPTION), errmsg("Unhandled exception: %s", _exception.what()))
  );
  return 0;
}
catch( ... ) {
  ereport(
    ERROR,
    (errcode(ERRCODE_TRIGGERED_ACTION_EXCEPTION), errmsg("Unhandled unknown exception"))
  );
  return 0;
}

