require 'routemaster/models/job'

module Routemaster
  module Services
    # Enqueues a job `name` into `queue`, then wait `every` milliseconds.
    #
    # FIXME: consolidate multiple ticker threads into one with a timer set.
    class Ticker
      def initialize(queue:, name:, every:, delay:true)
        @queue = queue
        @name  = name
        @every = every
        @delay = delay
      end

      def call
        @queue.push Models::Job.new(name: @name, run_at: @delay ? (Routemaster.now + @every) : nil)
        sleep(1e-3 * @every)
      end
    end
  end
end
