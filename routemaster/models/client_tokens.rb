require 'routemaster/models'
require 'routemaster/mixins/redis'

module Routemaster
  module Models
    class ClientTokens < String
      include Mixins::Redis

      def get_all
        nil
      end

    end
  end
end
