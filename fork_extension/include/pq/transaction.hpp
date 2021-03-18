#pragma once

#include <memory>

extern "C" {
typedef struct pg_conn PGconn;
}

namespace ForkExtension::PostgresPQ {

  class CopyToReversibleTuplesTable;
  class CopyTuplesSession;

  class Transaction {
  public:
      explicit Transaction( std::shared_ptr< PGconn > _connection );
      virtual ~Transaction();

      void execute( const std::string& _sql ) const;
      std::unique_ptr< CopyToReversibleTuplesTable > startCopyToReversibleTuplesSession();
      std::unique_ptr< CopyTuplesSession > startCopyTuplesSession( const std::string& _table_name );
  private:
      std::shared_ptr< PGconn > m_connection;
  };

} // namespace ForkExtension
