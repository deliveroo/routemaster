require 'routemaster/services'
require 'routemaster/mixins/log'

# throttle |ˈθrɒt(ə)l|
#   noun
#   a device controlling the flow of fuel or power to
#   an engine: the engines were at full throttle.
#
module Routemaster
  module Services
    class Throttle
      MAX_HP = 100

      def initialize(batch: nil, subscriber: nil)
        @batch = batch
        @subscriber = subscriber || @batch.subscriber
      end

      # Always continue if the backoff is per batch.
      # Always continue if the Subscriber is perfectly healthy.
      #
      # If the Subscriber is not healthy, calculate what the
      # current backoff delay would be. If the Subscriber hasn't
      # been hit for an amount of time that exceeds the
      # calculated backoff, then the Subscriber has already
      # had enough time to recover and the delivery can be
      # attempted imemediately.
      #
      def should_deliver?
        return true if _strategy == :batch
        last_attempt = @subscriber.last_attempted_at
        return true unless last_attempt
        return true if @subscriber.health_points >= MAX_HP

        delay = _subscriber_backoff

        _stale_enough?(last_attempt, delay)
      end


      def retry_backoff
        if _strategy == :subscriber
          _subscriber_backoff
        else
          _batch_backoff
        end
      end


      private

      # Is a timestamp older than a certain time interval?
      #
      def _stale_enough?(timestamp, time_span)
        timestamp < (Routemaster.now - time_span)
      end


      def _subscriber_backoff
        hp = @subscriber.health_points
        _exponential_backoff(_health_to_severity(hp))
      end

      # Use incremental ranges (Fibonacci) to map a subscriber's
      # health points to a number of hypotetical failed attempts.
      #
      # Just an experiment, there are probably better ways to do this.
      #
      def _health_to_severity(hp)
        case hp
        when 100    then 0
        when 98..99 then 1
        when 95..97 then 2
        when 90..94 then 3
        when 82..89 then 4
        when 69..81 then 5
        when 48..68 then 6
        else             7
        end
      end


      def _batch_backoff
        failed_attempts = @batch.fail
        _exponential_backoff(failed_attempts)
      end


      # Uses a severity level to calculate an exponential backoff delay,
      # expressed in milliseconds.
      #
      def _exponential_backoff(severity)
        return 0 if severity == 0
        backoff = 1_000 * 2 ** [severity-1, _backoff_limit].min
        backoff + rand(backoff)
      end

      def _backoff_limit
        @@_backoff_limit ||= Integer(ENV.fetch('ROUTEMASTER_BACKOFF_LIMIT'))
      end

      def _strategy
        @@_strategy ||= ENV.fetch('ROUTEMASTER_BACKOFF_STRATEGY', :batch).to_sym
      end
    end
  end
end
