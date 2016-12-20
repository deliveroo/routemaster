require_relative 'config/bootstrap.rb'
require 'core_ext/string'
require 'routemaster/application'

Routemaster.configure(
  # One connection for every other Puma thread, based on the empirical
  # assumption that half the time is spent processing requests, half enqueuing
  # events/jobs.
  redis_pool_size: (Integer(ENV.fetch('PUMA_THREADS')) + 1) / 2 
)

run Routemaster::Application
