require 'dotenv'

require 'config/openssl'
require 'core_ext/string'
require 'routemaster/application'
require 'routemaster/services/scheduler'
require 'newrelic_rpm' if ENV['NEW_RELIC_LICENSE_KEY']

Dotenv.load!('.env')
Dotenv.overload('.env.local') if ENV['RACK_ENV'] == 'development'

run Routemaster::Application
