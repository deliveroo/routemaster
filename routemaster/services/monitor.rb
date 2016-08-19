require 'routemaster/services'
require 'routemaster/models/subscription'
require 'routemaster/services/deliver_metric'

module Routemaster
  module Services
    # Monitor system health, and send the info to external services
    class Monitor
      def initialize
        @dispatcher = Routemaster::Services::DeliverMetric.new
        @tags = [
          "env:#{ENV['RACK_ENV']}",
          'app:routemaster'
        ]
      end

      def call
        Routemaster::Models::Subscription.each do |subscription|
          @dispatcher.call(
            'subscription.queue.size',
            subscription.queue.length,
            @tags + ["subscription:#{subscription.subscriber}"]
          )

          @dispatcher.call(
            'subscription.queue.staleness',
            subscription.queue.staleness,
            @tags + ["subscription:#{subscription.subscriber}"]
          )
        end
      end
    end
  end
end
