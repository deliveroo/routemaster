File.expand_path('..', __FILE__).tap { |d| $:.unshift(d) unless $:.include?(d) }

require 'dotenv'
require 'config/openssl'
require 'routemaster/application'

Dotenv.load!
run Routemaster::Application
