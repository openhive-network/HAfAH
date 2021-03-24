#pragma once

namespace PsqlTools::ForkExtension {
    enum class OperationType: uint8_t {
        INSERT = 0, UPDATE = 1, DELETE = 2
    };
} // namespace PsqlTools::ForkExtension
