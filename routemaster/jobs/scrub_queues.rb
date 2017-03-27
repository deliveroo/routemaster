require 'routemaster/jobs'
require 'routemaster/models/queue'
require 'routemaster/services/worker'
require 'routemaster/mixins/log'
require 'routemaster/mixins/counters'

module Routemaster
  module Jobs
    class ScrubQueues
      include Mixins::Log
      include Mixins::Counters

      # resurrect jobs from workers that haven't been seen for this many milliseconds,
      MAX_AGE = 30_000

      def initialize(max_age: MAX_AGE)
        @max_age = max_age
      end
      
      def call
        Models::Queue.each do |q|
          q.scrub do |worker_id|
            worker = Services::Worker.new(id: worker_id)
            last_at = worker.last_at
            last_at.nil? || last_at <= Routemaster.now - @max_age
          end
        end
      rescue => e
        _log_exception(e)
        raise Models::Queue::Retry, 10_000
      end
    end
  end
end
