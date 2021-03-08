#pragma once

namespace ForkExtension::Sql {

    static constexpr auto CREATE_TUPLES_TABLE = "CREATE TABLE IF NOT EXISTS tuples(id integer, table_name text, tuple_prev bytea, tuple_old bytea)";
    static constexpr auto GET_STORED_TUPLE = "SELECT tuple_old FROM tuples ORDER BY id DESC";

} // namespace ForkExtension::Sql
