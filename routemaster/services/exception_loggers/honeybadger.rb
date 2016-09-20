require 'singleton'
require 'routemaster/services'
require 'routemaster/mixins/log'

module Routemaster
  module Services
    module ExceptionLoggers
      class Honeybadger
        include Singleton
        include Mixins::Log

        def initialize
          require 'honeybadger'
          honeybadger_config = ::Honeybadger::Config.new(
            env: ENV['RACK_ENV'],
            api_key: ENV.fetch('HONEYBADGER_API_KEY'),
            logger: _log,
          )
          ::Honeybadger.start(honeybadger_config)
        rescue KeyError
          abort 'Please install and configure honeybadger (or equivalent service) first!'
        end

        def process(e, _env = ENV['RACK_ENV'])
          ::Honeybadger.notify(e)
        end
      end
    end
  end
end
