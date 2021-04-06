#pragma once

#include <boost/optional.hpp>

#include <memory>
#include <string>

extern "C" {
struct tupleDesc;
typedef tupleDesc* TupleDesc;
struct HeapTupleData;
typedef HeapTupleData *HeapTuple;
} // extern "C"

namespace PsqlTools::PsqlUtils::Spi {

  class SelectResultIterator {
  public:
    ~SelectResultIterator();
    SelectResultIterator(const SelectResultIterator& ) = delete;
    SelectResultIterator(SelectResultIterator&& ) = delete;
    SelectResultIterator& operator=(const SelectResultIterator& ) = delete;
    SelectResultIterator& operator=(SelectResultIterator&& ) = delete;

    static std::shared_ptr<SelectResultIterator> create(std::string _query );

    const std::string& getQuery();
    TupleDesc getTupleDesc();
    boost::optional< HeapTuple > next();

  private:
    SelectResultIterator(std::string _query );

  private:
    const std::string m_query;
    uint32_t m_current_row_id = 0u;
  };

} // namespace PsqlTools::PsqlUtils::Spi
