require 'routemaster/services'
require 'routemaster/mixins/log'
module Routemaster
  module Services
    class Backoff
      include Mixins::Log

      def initialize(batch)
        @batch = batch
      end

      def calculate
        if _strategy == :subscriber
          _subscriber_backoff(@batch.subscriber)
        else
          attempts = @batch.fail
          _batch_backoff(attempts)
        end
      end


      private

      def _subscriber_backoff(subscriber)
        hp = subscriber.health_points
        last_attempt_at = subscriber.last_attempted_at
        raise NotImplementedError
      end


      def _batch_backoff(attempts)
        backoff = 1_000 * 2 ** [attempts-1, _backoff_limit].min
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
