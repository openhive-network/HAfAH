#include "include/postgres_common.hpp"

extern "C" {
#include "postgres.h"
#include "fmgr.h"

PG_MODULE_MAGIC;
}

std::once_flag DB_CLIENT_ONCE_FLAG;
std::unique_ptr< SecondLayer::PostgresPQ::DbClient > DB_CLIENT;

