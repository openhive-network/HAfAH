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

  class QueryResultIterator {
  public:
    ~QueryResultIterator();
    QueryResultIterator( const QueryResultIterator& ) = delete;
    QueryResultIterator( QueryResultIterator&& ) = delete;
    QueryResultIterator& operator=( const QueryResultIterator& ) = delete;
    QueryResultIterator& operator=( QueryResultIterator&& ) = delete;

    static std::shared_ptr<QueryResultIterator> create( std::string _query );

    const std::string& getQuery();
    TupleDesc getTupleDesc();
    boost::optional< HeapTuple > next();

  private:
    QueryResultIterator( std::string _query );

  private:
    const std::string m_query;
    uint32_t m_current_row_id = 0u;
  };

} // namespace PsqlTools::PsqlUtils::Spi
