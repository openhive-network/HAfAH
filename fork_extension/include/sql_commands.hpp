#pragma once

#define TUPLES_TABLE_NAME "tuples"
#define BACK_FROM_FORK_FUNCTION "back_from_fork"
#define ON_TABLE_CHANGE_FUNCTION "on_table_change"

namespace ForkExtension::Sql {

    static constexpr auto CREATE_TUPLES_TABLE = "CREATE TABLE IF NOT EXISTS " TUPLES_TABLE_NAME "(id SERIAL PRIMARY KEY, table_name text, operation smallint, tuple_old bytea, tuple_new bytea )";
    enum class TuplesTableColumns {
          Id = 0
        , TableName = 1
        , Operation = 2
        , OldTuple = 3
        , NewTuple = 4
    };

    static constexpr auto GET_STORED_TUPLES = "SELECT table_name, operation, tuple_old, tuple_new FROM tuples ORDER BY id DESC";

    static constexpr auto EMPTY_TUPLES = "DELETE FROM tuples";
} // namespace ForkExtension::Sql
