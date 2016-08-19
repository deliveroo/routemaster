require_relative 'config/bootstrap.rb'
require 'config/openssl'
require 'core_ext/string'
require 'routemaster/application'

run Routemaster::Application
