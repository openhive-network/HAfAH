#pragma once

#include "include/columns_iterator.hpp"

#include <string>
#include <vector>

extern "C" {
  struct varlena;
  typedef struct varlena bytea;
}

namespace ForkExtension {
  class IRelation {
    public:
      using PrimaryKeyColumns = std::vector< uint16_t >;

      virtual ~IRelation() = default;

      virtual PrimaryKeyColumns getPrimaryKeysColumns() const = 0;
      virtual ColumnsIterator getColumns() const = 0;
      virtual std::string createPkeyCondition( bytea* _relation_tuple_in_copy_format ) const = 0;
      virtual std::string getName() const = 0;
  };
} // namespace ForkExtension

