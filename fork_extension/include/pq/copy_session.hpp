#pragma once

#include <memory>
#include <string>

extern "C" {
  struct pg_conn;
}

namespace SecondLayer::PostgresPQ {

    class CopySession{
    public:
        CopySession( std::shared_ptr< pg_conn > _connection, const std::string& _table_name );
        ~CopySession();
        CopySession(const CopySession&) = delete;
        CopySession& operator=(const CopySession&) = delete;

        void push_data( const char* _data, uint32_t _size ) const;

    private:
        std::shared_ptr< pg_conn > m_connection;
        const std::string m_table_name;
    };

} // namespace SecondLayer

