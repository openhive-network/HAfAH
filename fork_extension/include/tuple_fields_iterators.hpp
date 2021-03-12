#pragma once

#include "include/postgres_includes.hpp"

namespace ForkExtension {

    /* Tuple in copy format
     * | number of fields | field 1 size(B) |  field 1 value  | field 2 size(B) | field 2 value   | ...
     * |        16b       |        32b      | field 1 size(B) |      32b        | field 2 size(B) | ...
     */
    class TuplesFieldIterator {
    public:
        struct Field {
            char* m_value;
            uint32_t m_size;
        };

        TuplesFieldIterator( bytea* _tuple_in_copy_format );
        ~TuplesFieldIterator() = default;

        Field get_field() const;
        bool atEnd() const;
    private:
        static constexpr auto NUMBER_OF_FIELDS_SIZE = 2; // Bytes
        static constexpr auto FIELD_SIZE_SIZE = 4; // Bytes
        char* m_tuple_bytes;
        uint16_t m_number_of_fields;
        const uint32_t m_tuple_size;
        uint16_t m_current_field_number;
        char* m_current_field;
    };
} // namespace ForkExtension