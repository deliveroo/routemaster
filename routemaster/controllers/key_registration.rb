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

      post '/api_keys', parse: :json do
        unless data.has_key? "service_name"
          halt 400, "expected 'service_name' key"
        end
        new_key = Models::ClientToken.generate_api_key(data["service_name"])
        [201, {'Location': env["PATH_INFO"]}, {'new_key': new_key}.to_json]
      end

      delete '/api_keys/:key_name' do
        Models::ClientToken.delete_key(params['key_name'])
        halt 204
      end
    end
  end
end
