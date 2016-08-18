require 'routemaster/mixins'

module Routemaster
  module Mixins
    module Assert
      private

      def _assert(value, message = nil)
        return if !!value
        raise ArgumentError.new(message)
      end
    end
  end
end
