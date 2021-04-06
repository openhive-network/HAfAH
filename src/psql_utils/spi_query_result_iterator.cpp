#include "spi_query_result_iterator.hpp"

#include "include/exceptions.hpp"

#include "include/psql_utils/postgres_includes.hpp"

#include <cassert>

using namespace std::string_literals;

namespace {
  std::weak_ptr< PsqlTools::PsqlUtils::Spi::QueryResultIterator > ITERATOR_INSTANCE;
}

namespace PsqlTools::PsqlUtils::Spi {

std::shared_ptr<QueryResultIterator>
QueryResultIterator::create( std::string _query ) {
  auto previous_result_it = ITERATOR_INSTANCE.lock();
  if ( ITERATOR_INSTANCE.lock() ) {
    THROW_RUNTIME_ERROR( "Cannot execute two queries with SPI. Result of query "s + previous_result_it->getQuery() + " is still in use"s );
  }

  std::shared_ptr< QueryResultIterator > new_iterator( new QueryResultIterator( std::move( _query ) ) );
  ITERATOR_INSTANCE = new_iterator;
  return new_iterator;
}

QueryResultIterator::QueryResultIterator( std::string _query ): m_query( std::move( _query ) )  {
  constexpr auto all_rows = 0l;
  auto result = SPI_execute( m_query.c_str(), true, all_rows );
  if ( result != SPI_OK_SELECT ) {
    THROW_INITIALIZATION_ERROR( "Cannot execute query "s + m_query );
  }
}

const std::string&
QueryResultIterator::getQuery() {
  return m_query;
}

} // namespace PsqlTools::PsqlUtils::Spi

