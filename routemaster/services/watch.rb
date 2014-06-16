require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/models/subscription'
require 'routemaster/services/receive'
require 'core_ext/safe_thread'

module Routemaster::Services
  class Watch
    include Routemaster::Mixins::Log
    include Routemaster::Mixins::Assert

    def initialize(max_events = nil)
      _assert (max_events.nil? || max_events > 0)
      @max_events = max_events
      @receivers  = {} # subscription -> receive service
    end

    def start
      SafeThread.new { run }
      sleep 10e-3 until running?
      self
    end

    def join
      sleep 10e-3 while running?
    end

    # Create Receive services for each subscription.
    # Poll the list of subscriptions regularly for news.
    #
    # TODO: stopping operation cleanly, possibly by trapping SIGTERM//SIGQUIT/SIGINT.
    # may be unnecessary given the acknowledgement mechanism.
    def run
      _log.info { 'starting watch service' }
      _assert !@running, 'already running'
      @running = true

      while @running
        _log.debug { "watch service loop: #{Routemaster::Models::Subscription.count} subscriptions" }
        Routemaster::Models::Subscription.each do |subscription|
          _add_subscription(subscription)
        end

        sleep 0.25
        Thread.pass
      end

      _log.debug { 'stopping all receive services' }
      @receivers.each_value(&:cancel)
      _log.debug { 'watch service completed' }
    rescue Exception => e
      binding.pry
    ensure
      @running = nil
    end


    def running?
      !!@running
    end


    def cancel
      return unless @running
      @running = false
      _log.info { 'waiting for watch service to stop' }
      sleep 10e-3 until @running.nil?
      self
    end

    private

    # add and start a Receive service, unless one exists
    def _add_subscription(subscription)
      @receivers[subscription.subscriber] ||= begin
        Receive.new(subscription, @max_events).start
      end
    end
  end
end
