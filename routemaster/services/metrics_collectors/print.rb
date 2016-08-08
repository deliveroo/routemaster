require 'singleton'
require 'routemaster/services'
require 'routemaster/mixins/log'

module Routemaster
  module Services
    module MetricsCollectors
      class Print
        include Mixins::Log
        include Singleton

        def perform(name, value, tags, output = nil)
          _log.info("#{name}:#{value} (#{tags.join(",")})")
        end

      end
    end
  end
end
