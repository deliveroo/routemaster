require 'routemaster/services'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/log_exception'

module Routemaster
  module Services
    class Pulse
      include Mixins::Redis
      include Mixins::LogException

      def run
        _redis_alive?
      end

      private

      def _redis_alive?
        _redis.ping
        true
      rescue Redis::CannotConnectError => e
        deliver_exception(e)
        false
      end
    end
  end
end
