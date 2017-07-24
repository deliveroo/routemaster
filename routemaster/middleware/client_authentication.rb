require 'routemaster/middleware'
require 'routemaster/models/client_token'
require 'rack/auth/basic'

module Routemaster
  module Middleware
    class ClientAuthentication < Rack::Auth::Basic
      def initialize(app)
        super(app, &method(:_authenticate))
      end

      def call(env)
        super(env)
      end

      private

      def _authenticate(token, _)
        Models::ClientToken.exists?(token)
      end
    end
  end
end
