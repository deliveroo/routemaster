require 'routemaster/models/base'
require 'routemaster/models/callback_url'
require 'routemaster/models/user'
require 'routemaster/models/subscription'

module Routemaster::Models
  class Subscriber < Routemaster::Models::Base
    TIMEOUT_RANGE = 0..3_600_000
    DEFAULT_TIMEOUT = 500
    DEFAULT_MAX_EVENTS = 100

    attr_reader :name

    def initialize(name:)
      @name = User.new(name)
      @_attributes = nil
    end

    def save
      save_attrs = _attributes.any?
      _redis.multi do |m|
        m.sadd('subscribers', @name)
        m.hmset(_key, *_attributes.to_a.flatten) if save_attrs
      end
      self
    end

    def reload
      @_attributes = nil
      self
    end

    def destroy
      Subscription.where(subscriber: self).each(&:destroy)
      _redis.multi do |m|
        m.del(_key)
        m.srem('subscribers', @name)
      end
    end

    def callback=(value)
      _attributes['callback'] = CallbackURL.new(value)
    end

    def callback
      _attributes['callback']
    end

    def timeout=(value)
      _assert value.kind_of?(Fixnum)
      _assert TIMEOUT_RANGE.include?(value)
      _attributes['timeout'] = value
    end

    def timeout
      raw = _attributes['timeout']
      return DEFAULT_TIMEOUT if raw.nil?
      raw.to_i
    end

    def max_events=(value)
      _assert value.kind_of?(Fixnum)
      _assert value > 0
      _attributes['max_events'] = value
    end

    def max_events
      raw = _attributes['max_events']
      return DEFAULT_MAX_EVENTS if raw.nil?
      raw.to_i
    end

    def uuid=(value)
      _assert value.kind_of?(String) unless value.nil?
      _attributes['uuid'] = value
    end

    def uuid
      _attributes['uuid']
    end

    def to_s
      "subscriber for '#{@name}'"
    end

    def ==(other)
      @name == other.name
    end

    def topics
      Subscription.where(subscriber: self).map(&:topic)
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

    def _attributes
      @_attributes ||= _redis.hgetall(_key)
    end

    def _key
      @_key ||= "subscriber:#{@name}"
    end
  end
end
