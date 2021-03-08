#pragma once

#include <memory>
#include <string>

extern "C" {
  struct pg_conn;
}

namespace ForkExtension::PostgresPQ {

    class CopySession{
    public:
        CopySession( std::shared_ptr< pg_conn > _connection, const std::string& _table_name );
        ~CopySession();
        CopySession(const CopySession&) = delete;
        CopySession& operator=(const CopySession&) = delete;

        template< typename _PushedType >
        void push_data( const _PushedType* _data, uint32_t _size ) const;

    private:
        void push_data_internal( const char* _data, uint32_t _size ) const;

    private:
        std::shared_ptr< pg_conn > m_connection;
        const std::string m_table_name;
    };

    template< typename _PushedType >
    inline void
    CopySession::push_data( const _PushedType* _data, uint32_t _size  ) const {
      push_data_internal( reinterpret_cast< const char* >( _data ), _size );
    }


    } // namespace ForkExtension

