#!/bin/sh

# it outs content of sql scripts in order of execution
cat data_schema.sql
echo "\n"
cat event_triggers.sql
echo "\n"
cat context.sql
echo "\n"
cat register_table.sql
echo "\n"
cat detach_table.sql
echo "\n"
cat back_from_fork.sql
echo "\n"

