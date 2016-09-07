require 'routemaster/services'
require 'routemaster/models/subscriber'
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
        Routemaster::Models::Subscriber.each do |subscriber|
          @dispatcher.call(
            'subscriber.queue.size',
            subscriber.queue.length,
            @tags + ["subscriber:#{subscriber.name}"]
          )

          @dispatcher.call(
            'subscriber.queue.staleness',
            subscriber.queue.staleness,
            @tags + ["subscriber:#{subscriber.name}"]
          )
        end
      end
    end
  end
end
