#pragma once

#include <functional>
#include <memory>
#include <mutex>
#include <string>

extern "C" {
typedef struct pg_conn PGconn;
}

namespace SecondLayer::PostgresPQ {

  class CopyToReversibleTuplesTable;
  class CopyTuplesSession;

  class DbClient final {
  public:
      ~DbClient();

      std::unique_ptr< CopyToReversibleTuplesTable > startCopyToReversibleTuplesSession();
      std::unique_ptr< CopyTuplesSession > startCopyTuplesSession( const std::string& _table_name );

      static DbClient& get();
  private:
      DbClient();
      std::string get_database_name() const;

  private:
      std::shared_ptr< PGconn > m_connection;
      static std::once_flag ms_dbclient_create_once;
      static std::unique_ptr< DbClient > ms_instance;
  };

} // namespace SecondLayer::PostgresPQ