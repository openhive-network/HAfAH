#include "include/initialization.hpp"

#include "include/postgres_includes.hpp"

#include "include/initializer.hpp"

extern "C" {
  PG_MODULE_MAGIC;
}

ForkExtension::Initializer GLOBAL_INITIALIZER;

