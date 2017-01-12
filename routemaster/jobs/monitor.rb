require 'routemaster/jobs'
require 'routemaster/models/subscriber'
require 'routemaster/models/batch'
require 'routemaster/services/deliver_metric'

module Routemaster
  module Jobs
    # Monitor system health, and send the info to external services
    class Monitor
      def initialize(dispatcher: Routemaster::Services::DeliverMetric.new)
        @dispatcher = dispatcher
        @tags = [
          "env:#{ENV['RACK_ENV']}",
          'app:routemaster'
        ]
      end

      def call
        Models::Batch.counters.each_pair do |type, data|
          data.each_pair do |name, count|
            @dispatcher.call(
              "subscriber.queue.#{type}",
              count,
              @tags + ["subscriber:#{name}"]
            )
          end
        end

        Models::Queue.each do |q|
          n_jobs = q.length
          n_due  = q.length(deadline: Routemaster.now)
          @dispatcher.call('jobs.count', n_due,          @tags + %W[queue:#{q.name} status:instant])
          @dispatcher.call('jobs.count', n_jobs - n_due, @tags + %W[queue:#{q.name} status:scheduled])
        end
      end
    end
  end
end
