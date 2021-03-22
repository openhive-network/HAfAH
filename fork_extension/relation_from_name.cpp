#include "include/relation_from_name.hpp"

#include "include/exceptions.hpp"
#include "include/relation_wrapper.hpp"

#include <cassert>

using namespace std::string_literals;

namespace ForkExtension {
RelationFromName::RelationFromName( const std::string& _relation_name ) {
  auto range = makeRangeVar( NULL, const_cast< char* >( _relation_name.c_str() ), -1 );

  if ( range == nullptr ) {
    THROW_INITIALIZATION_ERROR("Cannot open relation "s + _relation_name);
  }

  m_postgres_relation = heap_openrv( range, AccessShareLock );
  if ( m_postgres_relation == nullptr ) {
    THROW_INITIALIZATION_ERROR("Cannot open relation "s + _relation_name);
  }

  m_relation_wrapper.reset( new RelationWrapper( m_postgres_relation ) );
}

RelationFromName::~RelationFromName() {

  m_relation_wrapper.reset();

  heap_close(m_postgres_relation, NoLock);
}

IRelation::PrimaryKeyColumns
RelationFromName::getPrimaryKeysColumns() const {
  assert( m_relation_wrapper );
  return m_relation_wrapper->getPrimaryKeysColumns();
}

ColumnsIterator
RelationFromName::getColumns() const {
  assert( m_relation_wrapper );
  return m_relation_wrapper->getColumns();
}

std::string
RelationFromName::createPkeyCondition( bytea* _relation_tuple_in_copy_format ) const {
  assert( m_relation_wrapper );
  return m_relation_wrapper->createPkeyCondition( _relation_tuple_in_copy_format );
}
} // namespace ForkExtension



