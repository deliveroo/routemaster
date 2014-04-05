require 'routemaster'
require 'sinatra'
require 'routemaster/middleware/authentication'
require 'routemaster/controllers/pulse'
require 'routemaster/controllers/topics'

class Routemaster::Application < Sinatra::Base
  use Routemaster::Middleware::Authentication
  use Routemaster::Controllers::Pulse
  use Routemaster::Controllers::Topics
end

