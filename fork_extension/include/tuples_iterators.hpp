#pragma once

#include "include/postgres_includes.hpp"

namespace ForkExtension {

    /* Tuple in copy format
     * | number of fields | field 1 size(B) |  field 1 value  | field 2 size(B) | field 2 value   | ...
     * |        16b       |        32b      | field 1 size(B) |      32b        | field 2 size(B) | ...
     */
    class TuplesFieldIterator {
    public:
        TuplesFieldIterator( bytea* _tuple_in_copy_format ) : m_tuple_bytes( _tuple_in_copy_format ){}
    private:
        bytea* m_tuple_bytes;
    };
} // namespace ForkExtension