#include "include/psql_utils/relation.hpp"

#include "relation_from_name.hpp"
#include "relation_wrapper.hpp"

namespace ForkExtension {

  std::unique_ptr< IRelation >
  IRelation::create( const std::string& _relation_name ) {
    return std::unique_ptr< IRelation >( new RelationFromName( _relation_name ) );
  }

  std::unique_ptr< IRelation >
  IRelation::create( RelationData* _relation_data ) {
    return std::unique_ptr< IRelation >( new RelationWrapper( _relation_data ) );
  }
} // namespace ForkExtension

