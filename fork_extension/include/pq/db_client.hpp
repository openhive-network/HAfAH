#pragma once

#include <functional>
#include <memory>
#include <string>

extern "C" {
#include <libpq-fe.h>
}

namespace SecondLayer::PostgresPQ {

    class CopyToReversibleTuplesTable;
    class CopyTuplesSession;

    class DbClient {
    public:
        DbClient( const std::string& _database, const std::string& _user, const std::string& _password ); //may throw std::exception - RAII
        ~DbClient();

        std::unique_ptr< CopyToReversibleTuplesTable > startCopyToReversibleTuplesSession();
        std::unique_ptr< CopyTuplesSession > startCopyTuplesSession( const std::string& _table_name );
    private:
        std::shared_ptr< PGconn > m_connection;
    };

} // namespace SecondLayer::PostgresPQ