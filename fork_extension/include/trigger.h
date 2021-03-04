#pragma once

extern "C" {
#include "postgres.h"
#include "fmgr.h"
#include "commands/trigger.h"

PG_FUNCTION_INFO_V1(table_changed_service);
}
