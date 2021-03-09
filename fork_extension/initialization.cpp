#include "include/initialization.hpp"

#include "include/postgres_includes.hpp"

#include "include/initializer.hpp"

extern "C" {
  PG_MODULE_MAGIC;
}

// Could not use _PG_init because cannot create function with SPI interface
ForkExtension::Initializer GLOBAL_INITIALIZER;

