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
      if conn.sadd('subscriptions', @subscriber)
        _log.info { "new subscription by '#{@subscriber}'" }
      end
    end

    def callback=(value)
      # TODO: test the callback with an empty event batch
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

    # # TODO: yield events in batches
    # def listen
    #   _queue.subscribe(ack: false) do |delivery_info, properties, payload|
    #     begin
    #       yield [Event.load(payload)]
    #       bunny.ack(delivery_info.delivery_tag, false)
    #     rescue
    #       bunny.nack(delivery_info.delivery_tag, false)
    #       raise
    #     end
    #   end
    # end

    def to_s
      "subscription for '#{@subscriber}'"
    end 

    extend Enumerable

    def self.each
      conn.smembers('subscriptions').each { |s| yield new(subscriber: s) }
    end

    # ideally this would not be exposed, but binding topics
    # and subscriptions requires accessing this.
    def queue ; _queue ; end

    private

    def _queue
      @_queue ||= bunny.queue(_bunny_name(@subscriber), durable: true, auto_delete: false)
    end

    def _key
      @_key ||= "subscription/#{@subscriber}"
    end
  end
end
