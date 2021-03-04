#pragma once

#include "include/pq/db_client.hpp"

#include <memory>
#include <mutex>

extern std::once_flag DB_CLIENT_ONCE_FLAG;
extern std::unique_ptr< SecondLayer::PostgresPQ::DbClient > DB_CLIENT;