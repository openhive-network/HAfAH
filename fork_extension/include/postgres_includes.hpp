#pragma once

#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wunused-parameter"
extern "C" {
#include <postgres.h>
#include <fmgr.h>
#include <executor/spi.h>
#include <libpq-fe.h>
#include <utils/rel.h>
#include <utils/tuplestore.h>
#include <utils/lsyscache.h>
#include <utils/fmgrprotos.h>
#include <utils/fmgroids.h>
#include <c.h>
}
#pragma GCC diagnostic pop