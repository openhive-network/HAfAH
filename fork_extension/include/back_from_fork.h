#pragma once

extern "C" {
#include "postgres.h"
#include "fmgr.h"

PG_FUNCTION_INFO_V1(back_from_fork);
}

