require 'routemaster/middleware'
require 'rack/auth/basic'

module Routemaster
  module Middleware
    class Authentication
      def initialize(app)
        @app = Rack::Auth::Basic.new(app) { |u,p| _authenticate(u,p) }
      end

      def call(env)
        @app.call(env)
      end

      private

      def _authenticate(username, password)
        @_users ||= Set.new(
          ENV.fetch('ROUTEMASTER_CLIENTS', '').split(','))
        !! @_users.include?(username)
        # Find user by token here
        # Return boolean based on whether or not a user matches up with the token
      end
    end
  end
end
