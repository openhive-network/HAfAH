#pragma once

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
  };
} // namespace ForkExtension
