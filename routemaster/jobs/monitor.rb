require 'routemaster/jobs'
require 'routemaster/models/subscriber'
require 'routemaster/models/batch'
require 'routemaster/models/database'
require 'routemaster/models/counters'
require 'routemaster/services/metrics/emit'
require 'core_ext/env'

module Routemaster
  module Jobs
    # Monitor system health, and send the info to external services
    class Monitor
      def initialize(dispatcher: Routemaster::Services::Metrics::Emit.new)
        @dispatcher = dispatcher
        @tags = [
          "env:#{ENV.fetch('RACK_ENV')}",
          "app:#{ENV.ifetch('ROUTEMASTER_APP_NAME')}",
        ]
      end

      def call
        @dispatcher.batched do
          Models::Batch.gauges.each_pair do |type, data|
            data.each_pair do |name, count|
              @dispatcher.gauge(
                "subscriber.queue.#{type}",
                count,
                @tags + %W[subscriber:#{name}]
              )
            end
          end

          Models::Queue.each do |q|
            n_jobs = q.length
            n_due  = q.length(deadline: Routemaster.now)
            @dispatcher.gauge('jobs.count', n_due,          @tags + %W[queue:#{q.name} status:instant])
            @dispatcher.gauge('jobs.count', n_jobs - n_due, @tags + %W[queue:#{q.name} status:scheduled])
          end

          Models::Database.instance.tap do |db|
            @dispatcher.gauge('redis.bytes_used', db.bytes_used, @tags)
            @dispatcher.gauge('redis.max_mem',    db.max_mem,    @tags)
            @dispatcher.gauge('redis.low_mark',   db.low_mark,   @tags)
            @dispatcher.gauge('redis.high_mark',  db.high_mark,  @tags)
          end

          Models::Counters.instance.dump.each_pair do |(name, *tags),value|
            @dispatcher.counter(name, value, @tags + tags.map { |t| t.join(':') })
          end
        end
      end
    end
  end
end
