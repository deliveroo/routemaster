require 'routemaster/services'
require 'routemaster/mixins/log'
require 'routemaster/exceptions'

# throttle |ˈθrɒt(ə)l|
#   noun
#   a device controlling the flow of fuel or power to
#   an engine: the engines were at full throttle.
#
module Routemaster
  module Services
    class Throttle
      MAX_HP = 100

      def initialize(subscriber)
        @subscriber = subscriber
      end


      def check!(current_time)
        if delay = _halt_with_backoff?
          raise Exceptions::EarlyThrottle.new(delay, @subscriber.name)
        else
          @subscriber.attempting_delivery(current_time)
          true
        end
      end


      # in ms, integer
      #
      # hp == 0     => 3333ms
      # hp == 50    => 833ms
      # hp == 100   => 0ms
      #
      def retry_backoff
        hp = @subscriber.health_points
        ((MAX_HP - hp) ** 2 / 3).round
      end


      def notice_failure
        @subscriber.change_health_by(_damage_rate)
      end


      def notice_success
        @subscriber.change_health_by(_heal_rate)
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
      def _halt_with_backoff?
        return false if @subscriber.health_points >= MAX_HP

        last_attempt = @subscriber.last_attempted_at
        return false unless last_attempt

        delay = retry_backoff
        return false if _stale_enough?(last_attempt, delay)

        delay
      end


      # Is a timestamp older than a certain time interval?
      #
      def _stale_enough?(timestamp, time_span)
        timestamp < (Routemaster.now - time_span)
      end


      def _heal_rate
        @@_heal_rate ||= Integer(ENV.fetch('ROUTEMASTER_HP_HEAL_RATE', '1'))
      end


      def _damage_rate
        @@_damage_rate ||= Integer(ENV.fetch('ROUTEMASTER_HP_DAMAGE_RATE', '-2'))
      end
    end
  end
end
