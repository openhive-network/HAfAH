#pragma once

#include <string>

namespace ForkExtension {
  /* The object of this type is a global variable in initialization.hpp
   * In its ctro db is initialized and prepared to work with fork extenstion
   * Please add all db initialization inside the ctor
   */
  class Initializer {
  public:
      Initializer();
      ~Initializer() = default;
      Initializer( const Initializer& ) = delete;
      Initializer( const Initializer&& ) = delete;
      Initializer& operator=( const Initializer& ) = delete;
      Initializer& operator=( Initializer&& ) = delete;

  private:
      void initialize_tuples_table() const;
      void initialize_back_from_fork_function() const;

      bool function_exists( const std::string& _function_name ) const;
  };
} // namespace ForkExtension
