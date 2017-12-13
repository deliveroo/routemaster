require 'routemaster/mixins'
require 'new_relic/agent/method_tracer'

module Routemaster
  module Mixins
    module Newrelic
      include ::NewRelic::Agent::MethodTracer

      def trace_with_newrelic(name, &block)
        if nr_tracing_enabled?
          trace_execution_scoped([name]) do
            block.call
          end
        else
          block.call
        end
      end

      def nr_tracing_enabled?
        ENV.fetch('NEWRELIC_TRACKING_ENABLED', 'false') =~ /^(true|on|yes|1)$/i
      end
    end
  end
end
