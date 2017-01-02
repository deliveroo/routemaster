require 'routemaster/services'
require 'forwardable'

module Routemaster
  module Services
    module Metrics     
      class Emit
        extend Forwardable

        def initialize
          service = ENV.fetch('METRIC_COLLECTION_SERVICE', 'print')

          require "routemaster/services/metrics/#{service}_adapter"

          @adapter = case service
            when 'print'   then Metrics::PrintAdapter.instance
            when 'datadog' then Metrics::DatadogAdapter.instance
          end
        end

        delegate %i[batched counter gauge] => :@adapter
      end
    end
  end
end
