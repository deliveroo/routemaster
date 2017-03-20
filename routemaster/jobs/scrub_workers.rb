require 'routemaster/jobs'
require 'routemaster/services/worker'
require 'routemaster/mixins/log'
require 'routemaster/mixins/counters'

module Routemaster
  module Jobs
    class ScrubWorkers
      include Mixins::Log
      include Mixins::Counters

      # clear workers that haven't been seen for this many milliseconds
      MAX_AGE = 120_000

      def initialize(max_age: MAX_AGE)
        @max_age = max_age
      end
      
      def call
        Services::Worker.each do |w|
          last_at = w.last_at
          next if last_at.nil?
          next unless last_at <= Routemaster.now - @max_age
          _counters.incr('workers.scrubbed')
          w.cleanup
        end
      end
    end
  end
end

