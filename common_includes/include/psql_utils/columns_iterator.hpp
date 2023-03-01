#pragma once

#include <boost/optional.hpp>

#include <functional>

extern "C" {
  struct TupleDescData;
}

namespace PsqlTools::PsqlUtils {
    
  class ColumnsIterator {
  public:
    explicit ColumnsIterator( const TupleDescData& _desc ); // lifetime of _desc controlled by the postgres
    ~ColumnsIterator() = default;

    boost::optional<std::string> next();

  private:
    std::reference_wrapper< const TupleDescData > m_tuple_desc;
    uint16_t m_current_column;
  };
} // namespace PsqlTools::PsqlUtils
