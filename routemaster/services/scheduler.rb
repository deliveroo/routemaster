require 'routemaster/services'
require 'routemaster/models/queue'
require 'routemaster/mixins/log'

module Routemaster
  module Services
    class Scheduler
      include Mixins::Log

      TICK = 10e-3
      INTERVAL = 100 # schedule jobs every this many milliseconds

      def call
        next_at = Routemaster.now + INTERVAL

        Models::Queue.each do |q|
          jobs = q.schedule
          _log.debug { "scheduler: promoted #{jobs} jobs on queue.#{q.name}" }
        end

        sleep TICK while (block_given? ? yield : true) && Routemaster.now < next_at
      end
    end
  end
end
