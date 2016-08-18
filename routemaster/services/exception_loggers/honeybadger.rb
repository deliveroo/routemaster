require 'singleton'
require 'routemaster/services'

module Routemaster
  module Services
    module ExceptionLoggers
      class Honeybadger
        include Singleton

        def initialize
          require 'honeybadger'
          honeybadger_config = ::Honeybadger::Config.new(
            env: ENV['RACK_ENV'],
            api_key: ENV.fetch('HONEYBADGER_API_KEY')
          )
          ::Honeybadger.start(honeybadger_config)
        rescue KeyError
          abort 'Please install and configure honeybadger (or equivalent service) first!'
        end

        def process(e, env = ENV['RACK_ENV'])
          ::Honeybadger.notify(e)
        end
      end
    end
  end
end
