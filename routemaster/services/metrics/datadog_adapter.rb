require 'singleton'
require 'routemaster/services'

module Routemaster
  module Services
    module Metrics
      class DatadogAdapter
        include Singleton
        include MonitorMixin

        def initialize
          require 'dogapi'
          api_key = ENV.fetch('DATADOG_API_KEY')
          app_key = ENV.fetch('DATADOG_APP_KEY')
          @dog ||= Dogapi::Client.new(api_key, app_key)
          super
        rescue KeyError
          abort 'Please install and configure datadog (or equivalent service) first!'
        end

        def batched
          synchronize do
            @dog.batch_metrics do
              yield
            end
          end
        end

        def gauge(name, value, tags)
          synchronize do
            @dog.emit_point("routemaster.#{name}", value, tags: tags, type: __callee__.to_s)
          end
        end

        alias_method :counter, :gauge
      end
    end
  end
end
