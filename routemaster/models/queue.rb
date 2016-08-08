require 'routemaster/models'
require 'routemaster/models/message'
require 'routemaster/mixins/log'
require 'routemaster/mixins/redis'

module Routemaster
  module Models
    # Abstraction for a queue.
    # Takes a Subscription and allows to push Messages in and pull them out in
    # order.
    class Queue
      include Mixins::Log
      include Mixins::Redis

      attr_reader :subscription

      def initialize(subscription)
        @subscription = subscription
      end

      def pop
        # TODO: convert to Lua
        uid = _redis.rpop(_new_uuids_key)
        return if uid.nil?

        _redis.zadd(_pending_uuids_key, Routemaster.now, uid)

        payload = _redis.hget(_payloads_key, uid)
        if payload.nil?
          _log.error { "missing payload for message #{uid} in queue #{@subscription.subscriber}" }
          return
        end

        Message.new(payload, uid)
      end

      # Acknowledge a message, permanently removing it form the queue
      def ack(message)
        # TODO: convert to Lua
        _redis.multi do |m|
          m.zrem(_pending_uuids_key, message.uid)
          m.hdel(_payloads_key, message.uid)
        end
      end

      # Negative acknowledge a message, re-queuing it for redelivery
      def nack(message)
        # TODO: convert to Lua
        return unless _redis.zrem(_pending_uuids_key, message.uid)
        _redis.rpush(_new_uuids_key, message.uid)
      end

      def to_s
        "subscriber:#{@subscription.subscriber} id:0x#{object_id.to_s(16)}"
      end

      def inspect
        "<#{self.class.name} #{self}>"
      end

      module ClassMethods
        def push(subscriptions, message)
          # TODO: convert to Lua
          subscriptions.each do |sub|
            _redis.hset _payloads_key(sub), message.uid, message.payload
            _redis.lpush _new_uuids_key(sub), message.uid
          end
        end

        private

        def _payloads_key(subscription)
          "queue/data/#{subscription.subscriber}"
        end

        def _new_uuids_key(subscription)
          "queue/new/#{subscription.subscriber}"
        end

        def _pending_uuids_key(subscription)
          "queue/pending/#{subscription.subscriber}"
        end
      end
      extend ClassMethods

      private

      %w[payloads new_uuids pending_uuids].each do |m|
        define_method "_#{m}_key" do
          self.class.send(__method__, @subscription)
        end
      end
    end
  end
end

