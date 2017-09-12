require 'routemaster/controllers/base'
require 'routemaster/models/client_token'

module Routemaster
  module Controllers
    class ApiToken < Base
      get '/api_tokens', auth: :root do
        keys = Models::ClientToken.all
        halt 204 if keys.empty?
        keys.reduce([]) { |ary,(k,v)|
          ary << { name: v, token: k }
        }.to_json
      end

      post '/api_tokens', auth: :root, parse: :json do
        begin
          token = Models::ClientToken.create!(name: data['name'], token: data['token'])
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

      delete '/api_tokens/:token', auth: :root do
        Models::ClientToken.destroy!(token: params['token'])
        halt 204
      end
    end
  end
end
