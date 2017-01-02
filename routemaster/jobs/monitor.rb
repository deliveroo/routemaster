require 'routemaster/jobs'
require 'routemaster/models/subscriber'
require 'routemaster/models/batch'
require 'routemaster/models/database'
require 'routemaster/services/deliver_metric'
require 'core_ext/env'

module Routemaster
  module Jobs
    # Monitor system health, and send the info to external services
    class Monitor
      def initialize(dispatcher: Routemaster::Services::DeliverMetric.new)
        @dispatcher = dispatcher
        @tags = [
          "env:#{ENV.fetch('RACK_ENV')}",
          "app:#{ENV.ifetch('ROUTEMASTER_APP_NAME')}",
        ]
      end

      def call
        Models::Batch.gauges.each_pair do |type, data|
          data.each_pair do |name, count|
            @dispatcher.call(
              "subscriber.queue.#{type}",
              count,
              @tags + %W[subscriber:#{name}]
            )
          end
        end

        Models::Queue.each do |q|
          n_jobs = q.length
          n_due  = q.length(deadline: Routemaster.now)
          @dispatcher.call('jobs.count', n_due,          @tags + %W[queue:#{q.name} status:instant])
          @dispatcher.call('jobs.count', n_jobs - n_due, @tags + %W[queue:#{q.name} status:scheduled])
        end

        Models::Database.instance.tap do |db|
          @dispatcher.call('redis.bytes_used', db.bytes_used, @tags)
          @dispatcher.call('redis.max_mem',    db.max_mem,    @tags)
          @dispatcher.call('redis.low_mark',   db.low_mark,   @tags)
          @dispatcher.call('redis.high_mark',  db.high_mark,  @tags)
        end
      end
    end
  end
end
