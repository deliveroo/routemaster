require 'routemaster/models/base'
require 'routemaster/models/callback_url'
require 'routemaster/models/user'

module Routemaster::Models
  class Queue < Routemaster::Models::Base
    TIMEOUT_RANGE = 0..3_600_000
    
    attr_reader :subscriber

    def initialize(subscriber:)
      @subscriber = User.new(subscriber)
      conn.sadd('queues', @subscriber)
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
      return if raw.nil?
      raw.to_i
    end

    def max_events=(value)
      _assert value.kind_of?(Fixnum)
      _assert (value > 0)
      conn.hset(_key, 'max_events', value)
    end

    def max_events
      conn.hget(_key, 'max_events')
    end

    def uuid=(value)
      _assert value.kind_of?(String) unless value.nil?
      conn.hset(_key, 'uuid', value) 
    end

    def uuid
      conn.hget(_key, 'uuid')
    end

    extend Forwardable
    delegate %i(push peek pop length) => :_fifo

    private

    def _fifo
      @_fifo ||= Fifo.new("queue-#{@subscriber}")
    end

    def _key
      @_key ||= "queue/#{@subscriber}"
    end
  end
end
