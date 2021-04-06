#pragma once

#include <boost/optional.hpp>

#include <memory>

extern "C" {
struct tupleDesc;
typedef tupleDesc* TupleDesc;
struct HeapTupleData;
typedef HeapTupleData *HeapTuple;
} // extern "C"

namespace PsqlTools::PsqlUtils::Spi {
  class SelectResultIterator;

  class ISelectResult {
  public:
    virtual const std::string& getQuery() const= 0;
    virtual TupleDesc getTupleDesc() = 0;
    virtual boost::optional< HeapTuple > next() = 0;
  };

  class SpiSession {
    public:
      ~SpiSession();

      static std::shared_ptr< SpiSession > create();
      std::shared_ptr< ISelectResult > select( std::string _select_query ) const;
  private:
    SpiSession();
  };

} // namespace PsqlTools::PsqlUtilsSpi
