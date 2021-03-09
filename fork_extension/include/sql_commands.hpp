#pragma once

#define TUPLES_TABLE_NAME "tuples"
#define BACK_FROM_FORK_FUNCTION "back_from_fork"
#define ON_TABLE_CHANGE_FUNCTION "on_table_change"

namespace ForkExtension::Sql {

    static constexpr auto CREATE_TUPLES_TABLE = "CREATE TABLE IF NOT EXISTS " TUPLES_TABLE_NAME "(id integer, table_name text, tuple_prev bytea, tuple_old bytea)";
    static constexpr auto GET_STORED_TUPLES = "SELECT table_name, tuple_prev FROM tuples ORDER BY id ASC";
} // namespace ForkExtension::Sql
