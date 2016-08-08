require 'routemaster/mixins'

module Routemaster
  module Services
    module DeliverMetric

      protected

      def deliver(name, value, tags = [])
        service = ENV.fetch('METRIC_COLLECTION_SERVICE', 'print')

        begin
          require "routemaster/services/metrics_collectors/#{service}"
        rescue LoadError
          abort "Please install and configure metrics collection service first!"
        end

        # send the exception message to your choice of service!
        service = service.camelize
        MetricsCollectors.const_get(service)
          .instance.perform(name, value, tags)
      end
    end
  end
end
