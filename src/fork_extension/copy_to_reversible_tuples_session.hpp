#pragma once

#include "include/pq_utils/copy_tuples_session.hpp"
#include "operation_types.hpp"

#include <memory>

extern "C" {
  struct HeapTupleData;
} // extern "C"

namespace ForkExtension::PostgresPQ {
    class Transaction;

    class CopyToReversibleTuplesTable {
    public:
        explicit CopyToReversibleTuplesTable( Transaction& _transaction );
        ~CopyToReversibleTuplesTable();

        void push_delete(const std::string& _table_name, const HeapTupleData& _deleted_tuple, const TupleDesc& _tuple_desc );
        void push_insert(const std::string& _table_name, const HeapTupleData& _inserted_tuple, const TupleDesc& _tuple_desc );
        void push_update(const std::string& _table_name, const HeapTupleData& _old_tuple, const HeapTupleData& _new_tuple, const TupleDesc& _tuple_desc );

    private:
        void push_tuple_header();
        void push_id_field();
        void push_table_name( const std::string& _table_name );
        void push_operation( OperationType _operation);

    private:
        std::shared_ptr< CopyTuplesSession > m_copy_session;
        class TupleHeader;
    };

} // namespace ForkExtension::PostgresPQ
