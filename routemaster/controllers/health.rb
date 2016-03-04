require 'routemaster/controllers'
require 'sinatra'

class Routemaster::Controllers::Health < Sinatra::Base
  get /^\/health\/ping(|.json)$/ do
    content_type :json
    { pong: Time.now }.to_json
  end
end
