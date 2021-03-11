#include "include/postgres_includes.hpp"

#include "include/initializer.hpp"

extern "C" {
  PG_MODULE_MAGIC;

void _PG_init(void) {
  ForkExtension::Initializer initializer;
}

void _PG_fini(void) {

}

} // extern "C"

// Could not use _PG_init because cannot create function with SPI interface
//ForkExtension::Initializer GLOBAL_INITIALIZER;

