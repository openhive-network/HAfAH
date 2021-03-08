#pragma once

namespace ForkExtension {

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
