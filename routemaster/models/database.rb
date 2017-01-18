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
        bytes_used > high_mark
      end

      def empty_enough?
        bytes_used < low_mark
      end

      def bytes_used
        _redis.info('memory')['used_memory'].to_i
      end

      def low_mark
        max_mem - 2 * min_free
      end

      def high_mark
        max_mem - min_free
      end

      def max_mem
        ENV.fetch('ROUTEMASTER_REDIS_MAX_MEM').to_i
      end

      def min_free
        ENV.fetch('ROUTEMASTER_REDIS_MIN_FREE').to_i
      end

      def used_cpu_sys
        raw = _redis.info('cpu')[__callee__.to_s]
        return if raw.nil?
        (raw.to_f * 1e3).to_i
      end

      # used_cpu_user has identical implementation to used_cpu_sys,
      # it simply looks up a different entry in INFO CPU
      # (distinguished by __callee__)
      alias_method :used_cpu_user, :used_cpu_sys
    end
  end
end
