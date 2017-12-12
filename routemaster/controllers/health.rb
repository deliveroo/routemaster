require 'routemaster/controllers/base'

module Routemaster
  module Controllers
    class Health < Base
      get %r{/health/ping(|.json)}, auth: :none do
        content_type :json
        ping.to_json
      end

      get %r{/health}, auth: :none do
        content_type :json
        ping.to_json
      end

      private

      def ping
        { pong: Time.now }
      end
    end
  end
end
