#include "include/psql_utils/postgres_includes.hpp"

#include "include/initializer.hpp"

namespace {
    bool is_initialized = false;
}


extern "C" {
  PG_MODULE_MAGIC;

void _PG_init(void) {
  /* BEGIN WORKAROUND
   * The problem is that during initialization we want to add functions from the extension plugin (this *.so), what leads to
   * recursive calls of _PG_init because postgres mark the dll as loaded (by adds it to the list of loaded plugins) after
   * finishing _PG_init. Look at dfmgr.c in postgres sources. The side effect of this workaround  is additional one more
   * reduntand *.so file in postgres internal lists.
   */
  if ( is_initialized ) {
    return;
  }
  is_initialized = true;
  // END WORKAROUND
  ForkExtension::Initializer initializer;
}

void _PG_fini(void) {

}

} // extern "C"

// Could not use _PG_init because cannot create function with SPI interface
//ForkExtension::Initializer GLOBAL_INITIALIZER;

