#include "include/exceptions.hpp"
#include "include/relation.hpp"
#include "include/postgres_includes.hpp"
#include "include/pq/copy_to_reversible_tuples_session.hpp"
#include "include/pq/db_client.hpp"
#include "include/pq/transaction.hpp"

#include "gen/git_version.hpp"

#include <cassert>
#include <functional>
#include <mutex>
#include <string>
#include <include/relation.hpp>

using ForkExtension::PostgresPQ::DbClient;

extern "C" {
PG_FUNCTION_INFO_V1(on_table_change);
}

void executeOnEachTuple( Tuplestorestate* _tuples, std::function< void(const HeapTupleData& _tuple) > _operation ) {
  if ( _tuples == nullptr) {
    THROW_RUNTIME_ERROR( "No tuples to process" );
  }

  auto slot = MakeTupleTableSlot();
  tuplestore_rescan( _tuples );
  while ( tuplestore_gettupleslot( _tuples, true, false, slot ) ) {
    if ( !slot->tts_tuple ) {
      THROW_RUNTIME_ERROR( "Virtual tuples are not supported" );
    }
    _operation( *slot->tts_tuple );
  }
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

  auto transaction = DbClient::currentDatabase().startTransaction();
  auto copy_session = transaction->startCopyToReversibleTuplesSession();
  TupleDesc tup_desc = trig_data->tg_relation->rd_att;
  const std::string trigg_table_name = SPI_getrelname(trig_data->tg_relation);

  if ( TRIGGER_FIRED_BY_DELETE(trig_data->tg_event) ) {
    if ( trig_data->tg_oldtable == nullptr ) {
      THROW_RUNTIME_ERROR( "No trigger tuples for delete" );
    }

    auto save_delete_operation = [&tup_desc,&copy_session,&trigg_table_name]( const HeapTupleData& _tuple ) {
        copy_session->push_delete(trigg_table_name, _tuple, tup_desc);
    };
    executeOnEachTuple( trig_data->tg_oldtable, save_delete_operation );

    return 0;
  }

  if ( TRIGGER_FIRED_BY_UPDATE(trig_data->tg_event) ) {
    LOG_WARNING("Table update not supported");
    return 0;
  }

  if ( TRIGGER_FIRED_BY_INSERT(trig_data->tg_event) ) {
    if ( trig_data->tg_newtable == nullptr ) {
      THROW_RUNTIME_ERROR( "No trigger tuples for insert" );
    }

    const std::string trigg_table_name = SPI_getrelname(trig_data->tg_relation);
    auto save_insert_operation = [&tup_desc,&copy_session,&trigg_table_name]( const HeapTupleData& _tuple ) {
      copy_session->push_insert(trigg_table_name, _tuple, tup_desc);
    };

    executeOnEachTuple( trig_data->tg_newtable, save_insert_operation );

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

