#include "include/endpoints/global_synchronization.hpp"
#include "include/exceptions.hpp"
#include "include/relation_wrapper.hpp"
#include "include/postgres_includes.hpp"
#include "include/pq/copy_to_reversible_tuples_session.hpp"
#include "include/pq/db_client.hpp"
#include "include/pq/transaction.hpp"
#include "include/tuples_iterator.hpp"

#include "gen/git_version.hpp"

#include <cassert>
#include <functional>
#include <mutex>
#include <string>
#include <include/relation_wrapper.hpp>

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
  /* Postgres is a multiprocess arch db, so each client connection works in a separated process
   * If the client starts 'back_from_fork', then restored tuples will immadiatly activate triggers
   * - on the same call stack as back_form_fork is executed, so we can easly block unneeded triggers with
   * a global variable.
   */
  if (ForkExtension::isBackFromForkInProgress() ) {
    return PointerGetDatum(NULL);
  }

  LOG_INFO( "Fired trigger 'on_table_change'" );

  if (!CALLED_AS_TRIGGER(fcinfo)) {
    THROW_RUNTIME_ERROR( "on_table_change not called by trigger manager" );
  }

  TriggerData* trig_data = reinterpret_cast<TriggerData*>( fcinfo->context );

  if ( !TRIGGER_FIRED_FOR_STATEMENT(trig_data->tg_event) ) {
    THROW_RUNTIME_ERROR("not supported statement trigger");
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
    return PointerGetDatum(NULL);
  }

  if ( TRIGGER_FIRED_BY_UPDATE(trig_data->tg_event) ) {
    if ( trig_data->tg_newtable == nullptr || trig_data->tg_oldtable == nullptr ) {
      THROW_RUNTIME_ERROR( "No trigger tuples for update" );
    }

    ForkExtension::TuplesStoreIterator old_tuples( trig_data->tg_oldtable );
    ForkExtension::TuplesStoreIterator new_tuples( trig_data->tg_newtable );

    while( auto old_tuple = old_tuples.next() ) {
      auto new_tuple = new_tuples.next();
      if ( !new_tuple ) {
        THROW_RUNTIME_ERROR( "Different number of new and old tuples during update operation" );
      }

      copy_session->push_update( trigg_table_name, old_tuple.get(), new_tuple.get(), tup_desc );
    }

    return PointerGetDatum(NULL);
  }

  if ( TRIGGER_FIRED_BY_INSERT(trig_data->tg_event) ) {
    if ( trig_data->tg_newtable == nullptr ) {
      THROW_RUNTIME_ERROR( "No trigger tuples for insert" );
    }

    auto save_insert_operation = [&tup_desc,&copy_session,&trigg_table_name]( const HeapTupleData& _tuple ) {
      copy_session->push_insert(trigg_table_name, _tuple, tup_desc);
    };

    executeOnEachTuple( trig_data->tg_newtable, save_insert_operation );

    return PointerGetDatum(NULL);
  }

  THROW_RUNTIME_ERROR( "Unexpected reason of trigger 'on_table_change'" );
  return PointerGetDatum(NULL);
}
catch ( std::exception& _exception ) {
  LOG_ERROR( "Unhandled exception: %s", _exception.what() );
  return PointerGetDatum(NULL);
}
catch( ... ) {
  LOG_ERROR( "Unhandled unknown exception" );
  return PointerGetDatum(NULL);
}

