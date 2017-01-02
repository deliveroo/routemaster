require 'singleton'
require 'routemaster/services'
require 'routemaster/mixins/log'

module Routemaster
  module Services
    module Metrics
      class PrintAdapter
        include Singleton
        include Mixins::Log

        def batched
          yield
        end

        def gauge(name, value, tags)
          _log.info("#{__method__}:#{name}:#{value} (#{tags.join(",")})")
        end

        alias_method :counter, :gauge
      end
    end
  end
end
