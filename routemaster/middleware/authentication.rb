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
        _tokens.include?(username)
      end

      def _tokens
        return @_tokens if @_tokens
        if raw = ENV['ROUTEMASTER_CLIENTS']
          warn 'ROUTEMASTER_CLIENTS is deprecated, use ROUTEMASTER_CLIENT_TOKENS'
        else
          raw = ENV.fetch('ROUTEMASTER_CLIENT_TOKENS', '')
        end
        
        @_tokens = Set.new(raw.split(','))
      end
    end
  end
end
