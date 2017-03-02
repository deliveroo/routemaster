require 'routemaster/controllers'
require 'sinatra'

module Routemaster
  module Controllers
    class Health < Sinatra::Base
      get %r{^/health/ping(|.json)$} do
        content_type :json
        { pong: Time.now }.to_json
      end
    end
  end
end
