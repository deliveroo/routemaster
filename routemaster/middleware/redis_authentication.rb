require 'routemaster/middleware'
require 'rack/auth/basic'

module Routemaster
  module Middleware
    class RedisAuthentication
      def initialize(app, options)
        @keys = options[:keys]
        p "#{__FILE__} - init keys - #{@keys.call}"
        @app = Rack::Auth::Basic.new(app) { |u,p| _authenticate(u,p) }
      end

      def call(env)
        @app.call(env)
      end

      private

      def _authenticate(_username, uuid)
        p "#{__FILE__} - keys - #{@keys.call}"
        p "#{__FILE__} - _username - #{_username}"
        p "#{__FILE__} - uuid - #{uuid}"
        p !! @keys.call.has_key?(uuid)
        !! @keys.call.has_key?(uuid)
      end
    end
  end
end
