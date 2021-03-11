#pragma once

#include <functional>
#include <memory>
#include <string>

extern "C" {
typedef struct pg_conn PGconn;
}

namespace ForkExtension::PostgresPQ {

  class CopyToReversibleTuplesTable;
  class CopyTuplesSession;

  class DbClient final {
  public:
      DbClient( const std::string& _db_name );
      ~DbClient();

      bool isConnected() const;

      std::unique_ptr< CopyToReversibleTuplesTable > startCopyToReversibleTuplesSession();
      std::unique_ptr< CopyTuplesSession > startCopyTuplesSession( const std::string& _table_name );

      // Because connecting to db is very slow connection to current db is hold globaly
      static DbClient& currentDatabase();

  private:
      // Connects to current db
      DbClient();
      std::string getCurrentDatabaseName() const;

  private:
      std::shared_ptr< PGconn > m_connection;
      static std::unique_ptr< DbClient > ms_instance;
  };

} // namespace ForkExtension::PostgresPQ