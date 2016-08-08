require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/log_exception'
require 'routemaster/models/subscription'
require 'routemaster/services/receive'
require 'core_ext/math'

module Routemaster
  module Services
    class Watch
      include Mixins::Log
      include Mixins::Assert
      include Mixins::LogException

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
          time_to_next_run = []
          _updated_receivers do |subscriber, receiver|
            _log.debug { "running receiver for #{subscriber} (#{receiver.batch_size} events)" }
            receiver.run
            time_to_next_run.push receiver.time_to_next_run
            _log.debug { "receiver for #{subscriber} want to run in #{receiver.time_to_next_run}ms" }
            break unless @running
          end

          break if rounds && (rounds -= 1).zero?

          # wait for the smallest +time_to_next_run+ but no longer than 10 seconds
          delay = [(time_to_next_run.min || DEFAULT_DELAY), MAX_DELAY].min
          _log.debug { "sleeping for #{delay} ms" }
          sleep delay.ms
        end

        _log.info { 'watch service completed' }
      rescue StandardError => e
        _log_exception(e)
        deliver_exception(e)
        raise
      ensure
        stop
      end

      def stop
        @running = false
      end

      private

      # Create receivers for any new subscriptions, and yield
      # subscriber/receiver pairs for all known subscriptions.
      def _updated_receivers
        @receivers ||= {}
        new_receivers = {}
        Models::Subscription.each do |subscription|
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
end
