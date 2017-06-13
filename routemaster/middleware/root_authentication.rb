require 'routemaster/middleware'
require 'rack/auth/basic'

module Routemaster
  module Middleware
    class RootAuthentication
      def initialize(app, protected_path)
        @app = app
        @protected_path = protected_path
      end

      def call(env)
        app = @app
        if protected_path?(env)
          app = Rack::Auth::Basic.new(app) { |u,p| _authenticate(u,p) }
        end

        app.call(env)
      end

      private

      def protected_path?(env)
        @protected_path === env["PATH_INFO"]
      end

      def _authenticate(uuid, _username)
        ENV.fetch('ROUTEMASTER_ROOT_KEY') == uuid
      end
    end
  end
end
