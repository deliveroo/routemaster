require 'routemaster/mixins'
require 'routemaster/models/counters'

module Routemaster
  module Mixins
    module Counters
      protected

      def _counters
        Models::Counters.instance
      end
    end
  end
end

