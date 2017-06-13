require 'routemaster/middleware'
require 'routemaster/models/client_token'
require 'rack/auth/basic'

module Routemaster
  module Middleware
    class ClientAuthentication
      def initialize(app)
        @app = Rack::Auth::Basic.new(app) { |u,p| _authenticate(u,p) }
      end

      def call(env)
        @app.call(env)
      end

      private

      def _authenticate(uuid, _username)
        Models::ClientToken.exists?(uuid)
      end
    end
  end
end
