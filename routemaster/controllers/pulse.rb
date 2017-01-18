require 'routemaster/controllers'
require 'routemaster/services/pulse'
require 'routemaster/models/queue'
require 'sinatra'

module Routemaster
  module Controllers
    class Pulse < Sinatra::Base
      get '/pulse' do
        has_pulse = Services::Pulse.new.run
        halt(has_pulse ? 204 : 500)
      end

      get '/pulse/scaling' do
        count = Models::Queue.reduce(0) do |accum,q|
          accum + q.length(deadline: Routemaster.now + Integer(ENV.fetch('ROUTEMASTER_SCALING_DEADLINE')))
        end
        if count >= Integer(ENV.fetch('ROUTEMASTER_SCALING_THRESHOLD'))
          sleep 1
        end
        halt 204
      end
    end
  end
end
