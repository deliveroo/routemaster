require 'routemaster/middleware'
require 'rack/auth/basic'

module Routemaster
  module Middleware
    class RootAuthentication < Rack::Auth::Basic
      def initialize(app, protected_paths: /.*/)
        @protected_paths = protected_paths
        @_app = app
        super(app, &method(:_authenticate))
      end

      def call(env)
        if env.fetch('PATH_INFO') =~ @protected_paths
          super(env)
        else
          @_app.call(env)
        end
      end

      private

      def _authenticate(token, _)
        ENV.fetch('ROUTEMASTER_ROOT_KEY') == token
      end
    end
  end
end
