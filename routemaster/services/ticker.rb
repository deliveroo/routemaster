require 'routemaster/models/job'

module Routemaster
  module Services
    # Enqueues a job `name` into `queue`, then wait `every` milliseconds.
    class Ticker
      TICK = 10e-3

      def initialize(queue:, name:, every:, delay:true)
        @queue = queue
        @name  = name
        @every = every
        @delay = delay
      end

      def call
        next_at = Routemaster.now + @every
        @queue.push Models::Job.new(name: @name, run_at: @delay ? next_at : nil)
        sleep TICK while (block_given? ? yield : true) && Routemaster.now < next_at
      end
    end
  end
end
