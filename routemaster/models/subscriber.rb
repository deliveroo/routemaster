require 'routemaster/models/base'
require 'routemaster/models/callback_url'
require 'routemaster/models/user'
require 'routemaster/models/queue'

module Routemaster::Models
  class Subscriber < Routemaster::Models::Base
    TIMEOUT_RANGE = 0..3_600_000
    DEFAULT_TIMEOUT = 500
    DEFAULT_MAX_EVENTS = 100

    attr_reader :subscriber

    def initialize(subscriber:)
      @subscriber = User.new(subscriber)
      if _redis.sadd('subscribers', @subscriber)
        _log.info { "new subscriber by '#{@subscriber}'" }
      end
    end

    def destroy
      topics.each { |t| t.subscribers.remove(self) }
      _redis.del(_key)
      _redis.srem('subscribers', @subscriber)
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
      "subscriber for '#{@subscriber}'"
    end

    def topics
      Routemaster::Models::Topic.all.select do |t|
        t.subscribers.include?(self)
      end
    end

    def all_topics_count
      topics.reduce(0) { |sum, topic| sum += topic.get_count }
    end

    def queue
      @queue ||= Routemaster::Models::Queue.new(self)
    end

    extend Enumerable

    def self.each
      _redis.smembers('subscribers').each { |s| yield new(subscriber: s) }
    end

    def self.find(name)
      return unless _redis.sismember('subscribers', name) 
      new(subscriber: name)
    end

    def inspect
      "<#{self.class.name} subscriber=#{@subscriber}>"
    end

    private

    def _key
      @_key ||= "subscriber:#{@subscriber}"
    end
  end
end
