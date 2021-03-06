require 'routemaster/controllers/base'

module Routemaster
  module Controllers
    class Health < Base
      get %r{^/health$}, auth: :none do
        content_type :json
        {}.to_json
      end

      get %r{^/health/ping(|.json)$}, auth: :none do
        content_type :json
        { pong: Time.now }.to_json
      end
    end
  end
end
