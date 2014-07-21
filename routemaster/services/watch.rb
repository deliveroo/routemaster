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

    def initialize(max_events = nil)
      @max_events = max_events || 100
      _assert (@max_events > 0)
    end

    # Create Receive services for each subscription.
    # Poll the list of subscriptions regularly for news.
    #
    # TODO: stopping operation cleanly, possibly by trapping SIGTERM//SIGQUIT/SIGINT.
    # may be unnecessary given the acknowledgement mechanism.
    def run(rounds = nil)
      _log.info { 'starting watch service' }
      @running = true

      while @running
        _log.debug { "round #{rounds}" } if rounds
        _updated_receivers do |subscriber, receiver|
          _log.debug { "running receiver for #{subscriber}" }
          receiver.run
          break unless @running
        end

        break if rounds && (rounds -= 1).zero?

        # TODO: if no messages where received, sleep
        # for half the minimum subscription timeout (or 50ms)
        sleep 50.ms
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
