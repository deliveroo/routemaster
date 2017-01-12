require_relative 'config/bootstrap.rb'
require 'core_ext/string'
require 'routemaster/application'

Routemaster.configure(
  redis_pool_size: Integer(ENV.fetch('PUMA_THREADS'))
)

run Routemaster::Application
