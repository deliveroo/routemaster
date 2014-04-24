require 'routemaster'
require 'sinatra'
require 'raven'
require 'routemaster/middleware/authentication'
require 'routemaster/controllers/pulse'
require 'routemaster/controllers/topics'
require 'routemaster/controllers/subscription'

class Routemaster::Application < Sinatra::Base
  use Raven::Rack

  use Routemaster::Middleware::Authentication
  use Routemaster::Controllers::Pulse
  use Routemaster::Controllers::Topics
  use Routemaster::Controllers::Subscription

  not_found do
    content_type 'text/plain'
    body ''
  end
end
