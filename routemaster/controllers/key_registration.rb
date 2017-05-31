require 'routemaster/controllers'
require 'routemaster/controllers/parser'
require 'routemaster/mixins/redis'
require 'routemaster/models/client_token'
require 'sinatra/base'
require 'securerandom'

module Routemaster
  module Controllers
    class KeyRegistration < Sinatra::Base
      register Parser

      use Middleware::Authentication, {keys:-> { {ENV['ROUTEMASTER_ROOT_KEY'] => "root"}}}

      # TODO: Think about whether these are the keys we actually want
      CREATE_KEYS = %w(service_name owner)

      get '/api_keys' do
        keys = Models::ClientToken.get_all
        halt 204 if keys.nil?
        keys.to_json
      end

      post '/api_keys', parse: :json do
        if (data.keys - CREATE_KEYS).any?
          halt 400, "bad data in payload #{data.keys}"
        end
        new_key = Models::ClientToken.generate_api_key(data)
        status 201
        {"new_key": new_key}.to_json
      end

      delete '/api_keys/:key_name' do
        Models::ClientToken.delete_key(params['key_name'])
        halt 204
      end
    end
  end
end
