ADD_PSQL_EXTENSION(
    NAME hive_fork
    SOURCES context_rewind/data_schema.sql
            context_rewind/event_triggers.sql
            context_rewind/context.sql
            context_rewind/register_table.sql
            context_rewind/detach_table.sql
            context_rewind/back_from_fork.sql
            context_rewind/irreversible.sql
            hived_api.sql
)