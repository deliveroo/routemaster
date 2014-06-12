File.expand_path('..', __FILE__).tap { |d| $:.unshift(d) unless $:.include?(d) }

require 'dotenv'
require 'config/openssl'
require 'core_ext/string'
require 'routemaster/application'

require 'newrelic_rpm' if ENV['NEW_RELIC_LICENSE_KEY']

Dotenv.load!
run Routemaster::Application
