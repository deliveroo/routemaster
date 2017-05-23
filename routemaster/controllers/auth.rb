require 'routemaster/controllers'
require 'routemaster/controllers/parser'
require 'json'
require 'sinatra'
require 'byebug'

module Routemaster
  module Controllers
    class Auth < Sinatra::Base
      register Parser

      post '/auth' do
        # request body contains api_key and api_secret (or use basic auth headers)
        # check credentials against mnohub idm
        # return token if successful
        {message: 'path is working'}.to_json
      end
    end
  end
end
