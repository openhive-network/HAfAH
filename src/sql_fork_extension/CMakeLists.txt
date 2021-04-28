ADD_PSQL_EXTENSION(
    NAME hive_fork
    SOURCES data_schema.sql
            event_triggers.sql
            context.sql
            register_table.sql
            detach_table.sql
            back_from_fork.sql
)