#pragma once

#include <functional>
#include <vector>

extern "C" {
  struct RelationData;
}

namespace ForkExtension {

  class Relation {
    public:
      using PrimaryKeyColumns = std::vector< uint16_t >;

      Relation( RelationData& _relation ); // assumed that postgres controll the lifetime of _relation
      ~Relation() = default;

      PrimaryKeyColumns getPrimaryKeysColumns() const;

  private:
      std::reference_wrapper<RelationData> m_relation;
  };

} // namespace ForkExtension

