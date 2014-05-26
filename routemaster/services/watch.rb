require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/models/subscription'
require 'routemaster/services/consume'

module Routemaster::Services
  class Watch
    include Routemaster::Mixins::Log
    include Routemaster::Mixins::Assert

    def initialize(max_events = nil)
      _assert (max_events.nil? || max_events > 0)
      @max_events = max_events
      @consumers  = []
    end

    # TODO: reacting to new queues. Possibly with a kill message on an internal
    # transient queue.
    # TODO: stopping operation cleanly, possibly by trapping SIGTERM//SIGQUIT/SIGINT.
    # may be unnecessary given the acknowledgement mehanism.
    def run
      _log.info { 'starting watch service' }

      @consumers =
      Routemaster::Models::Subscription.map do |subscription|
        Consume.new(subscription, @max_events)
      end

      @threads = @consumers.map do |consumer|
        Thread.new { consumer.run }
      end

      # in case there are no consumers, sentinel thread
      @threads << _noop_thread if @threads.empty?

      _log.debug { 'started watch service' }
      @threads.each(&:join)
    end


    def stop
      _log.info { 'stopping watch service' }
      @consumers.each(&:stop)
      @_noop_thread.terminate
    end

    private

    def _noop_thread
      @_noop_thread ||= Thread.new { sleep(60) }
    end
  end
end
