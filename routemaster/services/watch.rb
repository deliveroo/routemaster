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
    def run
      _log.info { 'starting watch service' }
      @running = true

      while @running
        _updated_receivers do |receiver|
          receiver.run
          break unless @running
        end

        Thread.pass
      end

      _log.debug { 'watch service completed' }
    rescue StandardError => e
      _log_exception(e)
      raise
    ensure
      stop
    end

    def stop
      @running = false
    end


    # def running?
    #   !!@running
    # end


    # def cancel
    #   return unless @running
    #   @running = false
    #   _log.info { 'waiting for watch service to stop' }
    #   sleep(10.ms) until @running.nil?
    #   self
    # end

    private

    def _updated_receivers
      @receivers ||= {}
      new_receivers = {}
      Routemaster::Models::Subscription.each do |subscription|
        subscriber = subscription.subscriber
        _log.info { "watch service loop: adding subscription for '#{subscriber}" }
        new_receivers[subscriber] = @receivers.fetch(subscriber) {
          Receive.new(subscription, @max_events)
        }
      end
      @receivers = new_receivers
      @receivers.each_value { |r| yield r }
    end

    # add and start a Receive service, unless one exists
    # def _add_subscription(subscription)
    #   @receivers[subscription.subscriber] ||= begin
    #     _log.info { "watch service loop: adding subscription for '#{subscription.subscriber}" }
    #     Receive.new(subscription, @max_events).start
    #   end
    # end
  end
end
