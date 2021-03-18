#include "include/tuples_iterator.hpp"

#include "include/exceptions.hpp"
#include "include/postgres_includes.hpp"

#include <cassert>

namespace ForkExtension {

TuplesStoreIterator::TuplesStoreIterator( Tuplestorestate& _tuples ) : m_tuples( _tuples ) {
  m_slot = MakeTupleTableSlot();
  if ( !m_slot ) {
    THROW_RUNTIME_ERROR( "Cannot create tuples slot" );
  }
  tuplestore_rescan( &m_tuples.get() );
}


boost::optional< HeapTupleData& >
TuplesStoreIterator::next() {
  if ( !tuplestore_gettupleslot( &m_tuples.get(), true, false, m_slot ) )
    return boost::optional< HeapTupleData& >();

  return boost::optional< HeapTupleData& >( *m_slot->tts_tuple );
}
} // namespace ForkExtension
