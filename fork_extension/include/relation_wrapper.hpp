#pragma once

#include "include/relation.hpp"

#include <vector>

extern "C" {
  struct RelationData;
  struct varlena;
  typedef struct varlena bytea;
}

namespace ForkExtension {

  /* It implements IRelation with wrapping postgres RelationData structure.
   * The lifetime of the RelationData is controlled outside the class (RelationWrapper is not a owner of RelationData
   */
  class RelationWrapper
          : public IRelation {
    public:
      using PrimaryKeyColumns = std::vector< uint16_t >;

      RelationWrapper(RelationData* _relation );
      ~RelationWrapper() = default;

      PrimaryKeyColumns getPrimaryKeysColumns() const override;
      ColumnsIterator getColumns() const override;
      std::string createPkeyCondition( bytea* _relation_tuple_in_copy_format ) const override;

    private:
      RelationData* m_relation;
  };


} // namespace ForkExtension

