require 'routemaster/controllers'
require 'routemaster/controllers/parser'
require 'routemaster/middleware/root_authentication'
require 'routemaster/models/client_token'
require 'sinatra/base'

module Routemaster
  module Controllers
    class KeyRegistration < Sinatra::Base
      register Parser

      use Routemaster::Middleware::RootAuthentication, /^\/api_key.*/

      get '/api_keys' do
        keys = Models::ClientToken.get_all
        halt 204 if keys.empty?
        keys.to_json
      end

      post '/api_keys/:service_name', parse: :json do
        new_key = Models::ClientToken.generate_api_key(params['service_name'])
        status 200
        {'new_key': new_key}.to_json
      end

      delete '/api_keys/:existing_uuid' do
        Models::ClientToken.delete_key(params['existing_uuid'])
        halt 204
      end
    end
  end
end
