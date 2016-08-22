require 'routemaster/services'

module Routemaster
  module Services
    class DeliverMetric
      def initialize
        service = ENV.fetch('METRIC_COLLECTION_SERVICE', 'print')

        begin
          require "routemaster/services/metrics_collectors/#{service}"
        rescue LoadError
          abort "Please install and configure metrics collection service first!"
        end

        @collector =
          case service
          when 'print' then MetricsCollectors::Print.instance
          when 'datadog' then MetricsCollectors::Datadog.instance
          end
      end

      def call(name, value, tags = [])
        @collector.perform(name, value, tags)
      end
    end
  end
end
