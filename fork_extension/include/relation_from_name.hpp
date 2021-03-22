#pragma once

#include "include/relation.hpp"

#include <memory>

extern "C" {
struct RelationData;
}

namespace ForkExtension {
  class RelationWrapper;

  class RelationFromName
    : public IRelation {
  public:
    explicit RelationFromName( const std::string& _relation_name );
    ~RelationFromName();

    PrimaryKeyColumns getPrimaryKeysColumns() const override;
    ColumnsIterator getColumns() const override;
    std::string createPkeyCondition( bytea* _relation_tuple_in_copy_format ) const override;

  private:
      RelationData* m_postgres_relation;
      std::unique_ptr< RelationWrapper > m_relation_wrapper;
  };

} // namespace ForkExtension
