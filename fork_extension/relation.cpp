#include "include/relation.hpp"

#include "include/postgres_includes.hpp"

#include <cassert>

namespace ForkExtension {
Relation::Relation( RelationData& _relation )
  : m_relation( _relation ) {

}

Relation::PrimaryKeyColumns
Relation::getPrimaryKeysColumns() const {
  PrimaryKeyColumns result;

  Oid pkey_oid;
  auto columns_bitmap = get_primary_key_attnos( m_relation.get().rd_id, true, &pkey_oid );

  if ( columns_bitmap == nullptr ) {
    return result;
  }

  int32_t column = -1;
  while( (column = bms_next_member( columns_bitmap, column ) ) >= 0 ) {
    result.push_back( column + FirstLowInvalidHeapAttributeNumber );
  }
  return result;
}

ColumnsIterator
Relation::getColumns() const {
  return ColumnsIterator( *m_relation.get().rd_att );
}

} // namespace ForkExtension
