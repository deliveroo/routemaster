require 'routemaster/middleware'
require 'rack/auth/basic'

module Routemaster
  module Middleware
    class RootAuthentication
      def initialize(app)
        @app = Rack::Auth::Basic.new(app) { |u,p| _authenticate(u,p) }
      end

      def call(env)
        @app.call(env)
      end

      private

      def _authenticate(username, _pwd)
        ENV.fetch('ROUTEMASTER_ROOT_KEY') == username
      end
    end
  end
end
