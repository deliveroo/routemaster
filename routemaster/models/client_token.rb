require 'routemaster/models'
require 'routemaster/mixins/redis'
require 'securerandom'

module Routemaster
  module Models
    class ClientToken
      include Mixins::Redis

      PREFIX = "api_keys:"

      def self.get_all
        key_dump = {}
        existing_keys = _redis.keys "#{PREFIX}*"
        nil if existing_keys.nil?
        existing_keys.each do |key|
          key_dump[key.gsub(PREFIX, '')] = _redis.keys key
        end
        key_dump
      end

      def self.generate_api_key(service_name)
        unique_key = nil
        while unique_key.nil? do
          new_key = SecureRandom.uuid 
          unique_key = new_key unless _redis.exists "#{PREFIX}#{new_key}"
        end
        _redis.set("#{PREFIX}#{unique_key}", service_name)
        unique_key
      end

      def self.delete_key(key)
        _redis.del "#{PREFIX}#{key}"
      end
    end
  end
end