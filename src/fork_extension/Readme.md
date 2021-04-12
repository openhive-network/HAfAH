# Requirements
apt-get install libpq-dev postgresql-server-dev-all

# Installation
use `make install` to copy the plugin to postgress plugins directory 

# Starting plugin
1. To start plugin please execute as a postgres db client: `LOAD '$libdir/plugins/libfork_extension.so'`
2. create trigger on observed table for example:
```
CREATE TRIGGER on_table_change AFTER DELETE ON table_name
    REFERENCING OLD TABLE AS old_table
    FOR EACH STATEMENT EXECUTE PROCEDURE on_table_change();
```
3. execute `back_from_fork` function: `SELECT back_from_fork();` to revert delete operations on observed tables

