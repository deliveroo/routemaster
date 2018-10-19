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
          ::Honeybadger.configure do |c|
            c.env = ENV.fetch('RACK_ENV')
            c.api_key = ENV.fetch('HONEYBADGER_API_KEY')
            c.logger = _log
          end
        rescue KeyError
          abort 'Please install and configure honeybadger (or equivalent service) first!'
        end

        def process(e, _options = {})
          ::Honeybadger.notify(e)
        end
      end
    end
  end
end
