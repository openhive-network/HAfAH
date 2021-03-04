#pragma once

#include "include/pq/copy_tuples_session.hpp"

#include <memory>

extern "C" {
  struct HeapTupleData;
} // extern "C"

namespace SecondLayer::PostgresPQ {

    class CopyToReversibleTuplesTable : public CopyTuplesSession {
    public:
        explicit CopyToReversibleTuplesTable( std::shared_ptr< pg_conn > _connection );
        ~CopyToReversibleTuplesTable();

        void push_insert( const std::string& _table_name, const HeapTupleData& _new_tuple, const TupleDesc& _tuple_desc );

    private:
        void push_tuple_header();
        void push_id_field();
    private:
        class TupleHeader;
        static int32_t m_tuple_id; //TODO: only temporary solution, id may be a serilizer or must be initialized for each creation
    };

} // namespace SecondLayer::PostgresPQ
