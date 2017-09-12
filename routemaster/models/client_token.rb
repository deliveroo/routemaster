require 'routemaster/models'
require 'routemaster/models/user'
require 'routemaster/mixins/redis'
require 'securerandom'

module Routemaster
  module Models
    class ClientToken
      include Mixins::Redis

      KEY_BY_TOKEN   = 'api_tokens:by_token'.freeze

      def self.all
        _redis.hgetall KEY_BY_TOKEN
      end

      def self.exists?(key)
        _redis.hexists(KEY_BY_TOKEN, key)
      end

      def self.create!(name:, token: nil)
        service = User.new(name)
        token ||= '%s--%s' % [service, SecureRandom.hex(16)]
        token = User.new(token)
        _redis.hset(KEY_BY_TOKEN, token, service)
        token
      end

      def self.destroy!(token:)
        _redis.hdel(KEY_BY_TOKEN, token)
      end
    end
  end
end
