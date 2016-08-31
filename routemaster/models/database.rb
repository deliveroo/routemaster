require 'routemaster/models'
require 'routemaster/mixins/redis'
require 'singleton'

module Routemaster
  module Models
    # The (Redis) datastore
    class Database
      include Singleton
      include Mixins::Redis

      def too_full?
        (max_mem - bytes_used) < min_free
      end

      def empty_enough?
        (max_mem - bytes_used) > 2 * min_free
      end

      def bytes_used
        _redis.info('memory')['used_memory'].to_i
      end

      private

      def max_mem
        ENV.fetch('ROUTEMASTER_REDIS_MAX_MEM').to_i
      end

      def min_free
        ENV.fetch('ROUTEMASTER_REDIS_MIN_FREE').to_i
      end
    end
  end
end
