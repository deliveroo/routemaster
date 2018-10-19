require 'singleton'
require 'routemaster/services'
require 'routemaster/mixins/log'

module Routemaster
  module Services
    module ExceptionLoggers
      class Print
        include Mixins::Log
        include Singleton

        def process(e, _options = {})
          _log_exception(e)
        end
      end
    end
  end
end

