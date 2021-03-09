#pragma once

#define TUPLES_TABLE_NAME "tuples"
#define BACK_FROM_FORK_FUNCTION "back_from_fork"

namespace ForkExtension::Sql {

    static constexpr auto CREATE_TUPLES_TABLE = "CREATE TABLE IF NOT EXISTS " TUPLES_TABLE_NAME "(id integer, table_name text, tuple_prev bytea, tuple_old bytea)";
    static constexpr auto GET_STORED_TUPLES = "SELECT tuple_old FROM tuples ORDER BY id DESC";
    static constexpr auto CREATE_BACK_FROM_FORK_FUNCTION = "CREATE FUNCTION " BACK_FROM_FORK_FUNCTION "() RETURNS void AS '$libdir/plugins/libfork_extension.so', '" BACK_FROM_FORK_FUNCTION "' LANGUAGE C";

} // namespace ForkExtension::Sql
