require 'routemaster/models'
require 'routemaster/mixins/redis'
require 'securerandom'

module Routemaster
  module Models
    class ClientToken
      include Mixins::Redis

      REDIS_KEY = 'api_keys'.freeze

      def self.get_all
        _redis.hgetall REDIS_KEY
      end

      def self.exists?(key)
        _redis.hexists REDIS_KEY, key
      end

      def self.generate_api_key(service_name)
        new_key = SecureRandom.hex(16)
        _redis.hset(REDIS_KEY, new_key, service_name)
        new_key
      end

      def self.delete_key(key)
        _redis.hdel REDIS_KEY, key
      end
    end
  end
end
