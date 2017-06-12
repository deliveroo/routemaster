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

      class EarlyThrottle < StandardError
        attr_reader :message
        def initialize(subcriber_name)
          @message = "Throttling batch deliveries to the '#{subcriber_name}' subscriber."
        end
      end


      def initialize(batch: nil, subscriber: nil)
        @batch = batch
        @subscriber = subscriber || @batch.subscriber
      end


      def check!(current_time)
        if _should_deliver?
          @subscriber.attempting_delivery(current_time)
          true
        else
          raise EarlyThrottle, @subscriber.name
        end
      end


      def retry_backoff
        hp = @subscriber.health_points
        _exponential_backoff(_health_to_severity(hp))
      end


      private


      # Always continue if the Subscriber is perfectly healthy.
      #
      # If the Subscriber is not healthy, calculate what the
      # current backoff delay would be. If the Subscriber hasn't
      # been hit for an amount of time that exceeds the
      # calculated backoff, then the Subscriber has already
      # had enough time to recover and the delivery can be
      # attempted imemediately.
      #
      def _should_deliver?
        last_attempt = @subscriber.last_attempted_at
        return true unless last_attempt
        return true if @subscriber.health_points >= MAX_HP

        delay = retry_backoff

        _stale_enough?(last_attempt, delay)
      end


      # Is a timestamp older than a certain time interval?
      #
      def _stale_enough?(timestamp, time_span)
        timestamp < (Routemaster.now - time_span)
      end


      def _health_to_severity(hp)
        1.0 * (MAX_HP - hp) * (_backoff_limit+1) / MAX_HP
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
    end
  end
end
