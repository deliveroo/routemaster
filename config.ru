File.expand_path('..', __FILE__).tap { |d| $:.unshift(d) unless $:.include?(d) }

require 'dotenv'
require 'config/openssl'
require 'core_ext/string'
require 'routemaster/application'

if ENV['EXCEPTION_SERVICE_URL']
  require 'raven'
  Raven.configure do |config|
    config.dsn = ENV['EXCEPTION_SERVICE_URL']
    config.environments = %w[staging production test]
  end
end

Dotenv.load!
run Routemaster::Application
