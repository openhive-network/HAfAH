#pragma once

#include "copy_to_reversible_tuples_session.hpp"
#include "operation_types.hpp"

#include "include/psql_utils/spi_session.hpp"

#include <memory>
#include <string>

extern "C" {
struct HeapTupleData;
struct tupleDesc;
typedef tupleDesc* TupleDesc;
typedef HeapTupleData *HeapTuple;
typedef struct varlena bytea;
} // extern "C"

namespace PsqlTools::PostgresPQ {
  class Transaction;
  class CopyTuplesSession;
} // namespace PsqlTools::PostgresPQ

namespace PsqlTools::PsqlUtils {
  class IRelation;
} // namespace PsqlTools::PostgresPQ

namespace PsqlTools::ForkExtension {

  class BackFromForkSession {
  public:
    BackFromForkSession();
    ~BackFromForkSession();
    BackFromForkSession( BackFromForkSession& ) = delete;
    BackFromForkSession( BackFromForkSession&& ) = delete;
    BackFromForkSession& operator=( BackFromForkSession& ) = delete;
    BackFromForkSession& operator=( BackFromForkSession&& ) = delete;

    void backFromFork();
  private:
    void fetchStoredTuples();
    void setCurrentlyProcessedRelation( HeapTuple _tuple, TupleDesc _tupleDesc );
    void setCurrentlyProcessedCopySession();
    std::string getTableName( HeapTuple _tuple, TupleDesc _tupleDesc ) const;
    OperationType getOperationType( HeapTuple _tuple, TupleDesc _tupleDesc ) const;
    void revertInsert( HeapTuple _tuple, TupleDesc _tupleDesc );
    void revertUpdate( HeapTuple _tuple, TupleDesc _tupleDesc );
    void revertDelete( HeapTuple _tuple, TupleDesc _tupleDesc );
    void endCopySession();

  private:
    std::shared_ptr< PsqlUtils::Spi::SpiSession > m_spi_session;
    std::unique_ptr< PostgresPQ::Transaction > m_transaction;
    std::unique_ptr< PostgresPQ::CopyTuplesSession > m_copy_session;
    std::unique_ptr< PsqlUtils::IRelation > m_processed_relation;
  };

} // namespace PsqlTools::ForkExtension
