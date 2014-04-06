require 'routemaster/models/base'
require 'routemaster/models/callback_url'
require 'routemaster/models/user'

module Routemaster::Models
  class Subscription < Routemaster::Models::Base
    TIMEOUT_RANGE = 0..3_600_000
    DEFAULT_TIMEOUT = 500
    DEFAULT_MAX_EVENTS = 100
    
    attr_reader :subscriber

    def initialize(subscriber:)
      @subscriber = User.new(subscriber)
      conn.sadd('subscriptions', @subscriber)
    end

    def callback=(value)
      conn.hset(_key, 'callback', CallbackURL.new(value))
    end

    def callback
      conn.hget(_key, 'callback')
    end

    def timeout=(value)
      _assert value.kind_of?(Fixnum)
      _assert TIMEOUT_RANGE.include?(value)
      conn.hset(_key, 'timeout', value)
    end

    def timeout
      raw = conn.hget(_key, 'timeout')
      return DEFAULT_TIMEOUT if raw.nil?
      raw.to_i
    end

    def max_events=(value)
      _assert value.kind_of?(Fixnum)
      _assert (value > 0)
      conn.hset(_key, 'max_events', value)
    end

    def max_events
      raw = conn.hget(_key, 'max_events')
      return DEFAULT_MAX_EVENTS if raw.nil?
      raw.to_i
    end

    def uuid=(value)
      _assert value.kind_of?(String) unless value.nil?
      conn.hset(_key, 'uuid', value) 
    end

    def uuid
      conn.hget(_key, 'uuid')
    end

    def stale?
      oldest_event = buffer.peek
      return false if oldest_event.nil?
      oldest_event.timestamp + timeout < Routemaster.now
    end

    def buffer
      @_buffer ||= Fifo.new("buffer-#{@subscriber}")
    end

    extend Forwardable
    delegate %i(push peek pop length) => :_fifo

    private

    def _fifo
      @_fifo ||= Fifo.new("subscription-#{@subscriber}")
    end

    def _key
      @_key ||= "subscription/#{@subscriber}"
    end
  end
end
