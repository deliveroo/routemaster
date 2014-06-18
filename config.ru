require 'dotenv'
require 'config/openssl'
require 'core_ext/string'
require 'routemaster/application'

Dotenv.load!
run Routemaster::Application
