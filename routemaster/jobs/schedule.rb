require 'routemaster/jobs'
require 'routemaster/models/queue'
require 'routemaster/mixins/log'

module Routemaster
  module Jobs
    class Schedule
      include Mixins::Log

      def call
        Models::Queue.each do |q|
          jobs = q.schedule
          _log.debug { "scheduler: promoted #{jobs} jobs on queue.#{q.name}" }
        end
      end
    end
  end
end
