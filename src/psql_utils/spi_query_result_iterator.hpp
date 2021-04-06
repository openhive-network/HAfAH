#pragma once

#include <memory>
#include <string>

namespace PsqlTools::PsqlUtils::Spi {

  class QueryResultIterator {
  public:
    ~QueryResultIterator() = default;
    QueryResultIterator( const QueryResultIterator& ) = delete;
    QueryResultIterator( QueryResultIterator&& ) = delete;
    QueryResultIterator& operator=( const QueryResultIterator& ) = delete;
    QueryResultIterator& operator=( QueryResultIterator&& ) = delete;

    static std::shared_ptr<QueryResultIterator> create( std::string _query );
  private:
    QueryResultIterator( std::string _query );

    const std::string& getQuery();
  private:
    const std::string m_query;
  };
} // namespace PsqlTools::PsqlUtils::Spi
