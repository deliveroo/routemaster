require 'routemaster/middleware'
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

      def _authenticate(_username, uuid)
        keys = Models::ClientToken.get_all

        p "#{self.class} - keys - #{keys}"
        p "#{self.class} - _username - #{_username}"
        p "#{self.class} - uuid - #{uuid}"
        p keys.has_key?(uuid)

        keys.has_key?(uuid)
      end
    end
  end
end
