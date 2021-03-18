#pragma once

#include <memory>

extern "C" {
typedef struct pg_conn PGconn;
}

namespace ForkExtension::PostgresPQ {

    class Transaction {
    public:
        explicit Transaction( std::shared_ptr< PGconn > _connection );
        virtual ~Transaction();
    private:
        std::shared_ptr< PGconn > m_connection;
    };

} // namespace ForkExtension
