# The DSN can be found in Sentry by navigation to
# Account -> Projects -> [Project Name] -> [Member Name].
# Its template resembles the following:
# '{PROTOCOL}://{PUBLIC_KEY}:{SECRET_KEY}@{HOST}/{PATH}{PROJECT_ID}'

require 'singleton'
require 'routemaster/services'

module Routemaster
  module Services
    module ExceptionLoggers
      class Sentry
        include Singleton

        def initialize
          # Require Raven as late as possible.
          # ie. only when an exception is raised,
          # caught and handled here.
          require 'raven'
          Raven.configure do |config|
            config.dsn = ENV.fetch('EXCEPTION_SERVICE_URL')
            config.environments = [ENV['RACK_ENV']]
          end
        rescue KeyError
          abort 'Please install and configure sentry-raven (or equivalent service) first!'
        end

        def process(e, _options = {})
          evt = Raven::Event.capture_exception(e)
          Raven.send(evt) if evt
        end
      end
    end
  end
end
