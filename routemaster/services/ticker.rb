require 'routemaster/services/thread'

module Routemaster
  module Services
    # Runs its `callable`, then waits for `every` milliseconds.
    # Useful as a callable for a `Thread`.
    class Ticker
      def initialize(callable, every:)
        @every    = every
        @callable = callable
      end

      def call
        @callable.call
        sleep(1e-3 * @every)
      end
    end
  end
end
