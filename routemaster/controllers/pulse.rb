require 'routemaster/controllers'
require 'routemaster/services/pulse'
require 'sinatra'

class Routemaster::Controllers::Pulse < Sinatra::Base
  get '/pulse' do
    has_pulse = Routemaster::Services::Pulse.new.run
    halt(has_pulse ? :ok : 500)
  end
end
