require 'routemaster/models/base'
require 'routemaster/models/callback_url'
require 'routemaster/models/user'
require 'routemaster/models/queue'
require 'routemaster/models/subscription'

module Routemaster::Models
  class Subscriber < Routemaster::Models::Base
    TIMEOUT_RANGE = 0..3_600_000
    DEFAULT_TIMEOUT = 500
    DEFAULT_MAX_EVENTS = 100

    attr_reader :name

    def initialize(name:)
      @name = User.new(name)
      if _redis.sadd('subscribers', @name)
        _log.info { "new subscriber by '#{@name}'" }
      end
    end

    def destroy
      Subscription.where(subscriber: self).each(&:destroy)
      _redis.del(_key)
      _redis.srem('subscribers', @name)
    end

    def callback=(value)
      # TODO: test the callback with an empty event batch
      _redis.hset(_key, 'callback', CallbackURL.new(value))
    end

    def callback
      _redis.hget(_key, 'callback')
    end

    def timeout=(value)
      _assert value.kind_of?(Fixnum)
      _assert TIMEOUT_RANGE.include?(value)
      _redis.hset(_key, 'timeout', value)
    end

    def timeout
      raw = _redis.hget(_key, 'timeout')
      return DEFAULT_TIMEOUT if raw.nil?
      raw.to_i
    end

    def max_events=(value)
      _assert value.kind_of?(Fixnum)
      _assert (value > 0)
      _redis.hset(_key, 'max_events', value)
    end

    def max_events
      raw = _redis.hget(_key, 'max_events')
      return DEFAULT_MAX_EVENTS if raw.nil?
      raw.to_i
    end

    def uuid=(value)
      _assert value.kind_of?(String) unless value.nil?
      _redis.hset(_key, 'uuid', value)
    end

    def uuid
      _redis.hget(_key, 'uuid')
    end

    def to_s
      "subscriber for '#{@name}'"
    end

    def topics
      Subscription.where(subscriber: self).map(&:topic)
    end

    def all_topics_count
      topics.reduce(0) { |sum, topic| sum += topic.get_count }
    end

    def queue
      @queue ||= Routemaster::Models::Queue.new(self)
    end

    extend Enumerable

    def self.each
      _redis.smembers('subscribers').each { |s| yield new(name: s) }
    end

    def self.find(name)
      return unless _redis.sismember('subscribers', name) 
      new(name: name)
    end

    def inspect
      "<#{self.class.name} subscriber=#{@name}>"
    end

    private

    def _key
      @_key ||= "subscriber:#{@name}"
    end
  end
end
