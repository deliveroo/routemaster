require 'routemaster/models/job'

module Routemaster
  module Services
    # Enqueues a job `name` into `queue`, then wait `every` milliseconds.
    #
    # FIXME: consolidate multiple ticker threads into one with a timer set.
    class Ticker
      def initialize(queue:, name:, every:)
        @queue = queue
        @name  = name
        @every = every
      end

      def call
        @queue.push Models::Job.new(name: @name)
        sleep(1e-3 * @every)
      end

      def cleanup
        nil
      end
    end
  end
end
