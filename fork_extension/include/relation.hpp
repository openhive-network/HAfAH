#pragma once

#include "include/columns_iterator.hpp"

#include <functional>
#include <vector>

extern "C" {
  struct RelationData;
  struct varlena;
  typedef struct varlena bytea;
}

namespace ForkExtension {

  class Relation {
    public:
      using PrimaryKeyColumns = std::vector< uint16_t >;

      Relation( RelationData& _relation ); // assumed that postgres controll the lifetime of _relation
      ~Relation() = default;

      PrimaryKeyColumns getPrimaryKeysColumns() const; //returns sorted list of pkey columns number
      ColumnsIterator getColumns() const;
      std::string createPkeyCondition( bytea* _relation_tuple_in_copy_format ) const;

    private:
      std::reference_wrapper<RelationData> m_relation;
  };

} // namespace ForkExtension

