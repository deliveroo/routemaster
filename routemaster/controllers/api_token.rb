require 'routemaster/controllers'
require 'routemaster/controllers/parser'
require 'routemaster/middleware/root_authentication'
require 'routemaster/models/client_token'
require 'sinatra/base'

module Routemaster
  module Controllers
    class ApiToken < Sinatra::Base
      register Parser
      use Middleware::RootAuthentication, protected_paths: %r{^/api_tokens}

      get '/api_tokens' do
        keys = Models::ClientToken.all
        halt 204 if keys.empty?
        keys.reduce([]) { |ary,(k,v)|
          ary << { name: v, token: k }
        }.to_json
      end

      post '/api_tokens', parse: :json do
        begin
          token = Models::ClientToken.create!(name: data['name'])
        rescue ArgumentError => e
          halt 400, e.message
        end

        content_type :json
        status 201
        {
          token:  token,
          name:   data['name'],
        }.to_json
      end

      delete '/api_tokens/:token' do
        Models::ClientToken.destroy!(token: params['token'])
        halt 204
      end
    end
  end
end
