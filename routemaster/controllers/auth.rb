require 'routemaster/controllers'
require 'routemaster/models/client_token'
require 'sinatra/base'
require 'rack/auth/basic'

module Routemaster
  module Controllers
    module Auth
      def self.registered(app)
        app.helpers Helpers

        app.set :auth do |*types|
          condition do
            authenticators = types.map { |name| method(:"authenticate_#{name}") }
            @current_token = authenticators.map(&:call).compact.first
            unauthorized!(types) unless @current_token
          end
        end
      end

      module Helpers
        def current_token
          @current_token
        end

        def basic_auth
          auth = Rack::Auth::Basic::Request.new(request.env)

          return unless auth.provided? && auth.basic? && auth.credentials.size == 2
          yield *auth.credentials
        end

        def authenticate_root
          basic_auth do |token, _|
            ENV.fetch('ROUTEMASTER_ROOT_KEY') == token ? token : nil
          end
        end

        def authenticate_client
          basic_auth do |token, _|
            Models::ClientToken.exists?(token) ? token : nil
          end
        end

        def authenticate_none
          auth = Rack::Auth::Basic::Request.new(request.env)
          !auth.provided?
        end

        def unauthorized!(types)
          msg = types.map { |type|
            case type
            when :root    then 'a root token'
            when :client  then 'a client token'
            when :none    then 'no token'
            end
          }.join(', or ')
          
          content_type 'text/plain'
          headers['WWW-Authenticate'] = 'Basic'
          halt 401, "this endpoint requires authentication with #{msg}"
        end
      end
    end
  end
end
