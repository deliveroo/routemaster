require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/models/subscription'
require 'routemaster/services/receive'
require 'core_ext/safe_thread'
require 'core_ext/math'

module Routemaster::Services
  class Watch
    include Routemaster::Mixins::Log
    include Routemaster::Mixins::Assert

    MAX_DELAY = 30_000 # max milliseconds between iterations, in Routemaster's time unit
    DEFAULT_DELAY = 1_000 # default delay between iterations in absence of subscriptions

    # +max_events+ is the largest number of events fetched in a run
    # by receivers.
    def initialize(max_events = nil)
      @max_events = max_events || 100
      _assert (@max_events > 0)
    end

    # Create Receive services for each subscription.
    # Poll subscriptions regularly for news.
    def run(rounds = nil)
      _log.info { 'starting watch service' }
      @running = true

      while @running
        run_in = []
        _updated_receivers do |subscriber, receiver|
          receiver.run
          run_in.push receiver.run_in
          break unless @running
        end

        break if rounds && (rounds -= 1).zero?

        # wait for the smallest +run_in+ but no longer than 10 seconds
        delay = [(run_in.min || DEFAULT_DELAY), MAX_DELAY].min
        sleep delay.ms
      end

      _log.info { 'watch service completed' }
    rescue StandardError => e
      _log_exception(e)
      raise
    ensure
      stop
    end

    def stop
      @running = false
    end

    private

    def _updated_receivers
      @receivers ||= {}
      new_receivers = {}
      Routemaster::Models::Subscription.each do |subscription|
        subscriber = subscription.subscriber
        new_receivers[subscriber] = @receivers.fetch(subscriber) {
          _log.info { "watch detected new subscription for '#{subscriber}'" }
          Receive.new(subscription, @max_events)
        }
      end
      @receivers = new_receivers
      @receivers.each_pair { |p| yield p }
    end
  end
end
