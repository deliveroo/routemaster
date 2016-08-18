require 'routemaster/controllers'
require 'routemaster/services/pulse'
require 'sinatra'

module Routemaster
  module Controllers
    class Pulse < Sinatra::Base
      get '/pulse' do
        has_pulse = Services::Pulse.new.run
        halt(has_pulse ? 204 : 500)
      end
    end
  end
end
