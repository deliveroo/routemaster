require 'singleton'
require 'routemaster/services'
require 'routemaster/mixins/log'

module Routemaster
  module Services
    module ExceptionLoggers
      class NewRelic
        include Singleton
        include Mixins::Log

        def initialize
          abort 'Please install and configure NewRelic first' unless ENV['NEW_RELIC_LICENSE_KEY']

          require 'newrelic_rpm'
        end

        def process(e, _env = ENV['RACK_ENV'])
          ::NewRelic::Agent.notice_error(e)
        end
      end
    end
  end
end
