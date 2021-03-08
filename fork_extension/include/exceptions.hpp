#pragma once

#include <exception>

namespace ForkExtension {

// All custom C++ object may throws this exception formtheirs c-tors to implement RAII
class ObjectInitializationException : public std::runtime_error
{
public:
    explicit ObjectInitializationException( const std::string& _message ) : std::runtime_error( _message ){}
    ~ObjectInitializationException() = default;
};

} // namespace ForkExtension

