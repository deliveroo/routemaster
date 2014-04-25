require 'singleton'
require 'routemaster/services'

module Routemaster::Services::ExceptionLoggers
  class Sentry
    include Singleton

    def initialize
      require 'raven'
      Raven.configure do |config|
        config.dsn = ENV.fetch('EXCEPTION_SERVICE_URL')
        config.environments = [ENV['RACK_ENV']]
      end
    rescue LoadError => e
      $stderr.puts 'Please install and configure sentry-raven (or equivalent service) first!'
      abort
    end

    def process(e, env = ENV['RACK_ENV'])
      evt = Raven::Event.capture_exception(e)
      Raven.send(evt) if evt
    end

  end
end
