ADD_PSQL_EXTENSION(
    NAME hive_fork_manager
    SOURCES context_rewind/data_schema.sql
            context_rewind/names.sql
            context_rewind/triggers.sql
            context_rewind/event_triggers.sql
            context_rewind/register_table.sql
            context_rewind/detach_table.sql
            context_rewind/back_from_fork.sql
            context_rewind/irreversible.sql
            context_rewind/rewind_api.sql
            events_queue.sql
            forks.sql
            app_context.sql
            irreversible_blocks.sql
            reversible_blocks.sql
            blocks_views_for_contexts.sql
            state_provider.sql
            state_providers/accounts.sql
            hived_api_impl.sql
            app_api_impl.sql
            hived_api.sql
            app_api.sql
            authorization.sql
)