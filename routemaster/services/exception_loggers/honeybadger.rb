require 'singleton'
require 'routemaster/services'

module Routemaster::Services::ExceptionLoggers
  class Honeybadger
    include Singleton

    def initialize
      require 'honeybadger'

      ::Honeybadger.configure do |config|
        config.api_key = ENV.fetch('HONEYBADGER_API_KEY')
        config.development_environments = %w(development test)
        config.environment_name = ENV.fetch('RACK_ENV', 'development')
      end
    rescue KeyError
      abort 'Please install and configure honeybadger (or equivalent service) first!'
    end

    def process(e, env = ENV['RACK_ENV'])
      ::Honeybadger.notify(e)
    end
  end
end
