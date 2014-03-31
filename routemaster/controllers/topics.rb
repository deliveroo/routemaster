require 'routemaster/controllers'
require 'sinatra'

class Routemaster::Controllers::Topics < Sinatra::Base
  post '/topics/:name' do
    halt :ok
  end
end

