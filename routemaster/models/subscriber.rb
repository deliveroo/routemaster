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

    def initialize(name:, attributes: nil)
      @name = User.new(name)
      @_attributes = attributes
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
      _assert value.kind_of?(Integer)
      _assert TIMEOUT_RANGE.include?(value)
      _attributes['timeout'] = value
    end

    def timeout
      raw = _attributes['timeout']
      return DEFAULT_TIMEOUT if raw.nil?
      raw.to_i
    end

    def max_events=(value)
      _assert value.kind_of?(Integer)
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

    def health_points
      _attributes.fetch('health_points', '100').to_i
    end

    def change_health_by(offset)
      new_value = _redis_lua_run(
        'subscriber_change_health_by',
        keys: [_key],
        argv: [offset]
      )
      @_attributes = nil
      new_value
    end

    def last_attempted_at
      _attributes['last_attempted_at']&.to_i
    end

    def attempting_delivery(time = Routemaster.now)
      _write_attribute('last_attempted_at', time)
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

    module ClassMethods
      include Enumerable

      def each
        _redis.smembers(_index_key).each { |s| yield new(name: s) }
      end

      def find(name)
        return unless _redis.sismember(_index_key, name) 
        new(name: name)
      end

      # Load all subscribers with name in `name` (Array or single string)
      def where(name:)
        _redis_lua_run(
          'subscriber_all',
          keys: [_index_key, *Array(name).map { |n| _key(n) }],
          argv: Array(name)
        ).map do |n, data|
          new(name: n, attributes: Hash[*data])
        end
      end

      private 

      def _index_key
        'subscribers'
      end

      def _key(name)
        "subscriber:#{name}"
      end
    end
    extend ClassMethods

    def inspect
      "<#{self.class.name} subscriber=#{@name}>"
    end

    private

    def _attributes
      @_attributes ||= _redis.hgetall(_key)
    end

    def _key
      @_key ||= self.class.send(:_key, @name)
    end

    def _write_attribute(field, value)
      _redis.hset(_key, field, value)
      @_attributes = nil
      value
    end
  end
end
