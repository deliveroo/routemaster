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
        uid, payload = _redis_lua_run(
          'queue_pop',
          keys: [_new_uuids_key, _pending_uuids_key, _payloads_key],
          argv: [Routemaster.now])

        return if uid.nil?

        if payload.nil?
          _log.error { "missing payload for message #{uid} in queue #{@subscription.subscriber}" }
          return
        end

        Message.new(payload, uid)
      end

      # Acknowledge a message, permanently removing it form the queue
      def ack(message)
        _redis_lua_run('ack', keys: [_pending_uuids_key, _payloads_key], argv: [message.uid])
        self
      end

      # Negative acknowledge a message, re-queuing it for redelivery
      def nack(message)
        _redis_lua_run('nack', keys: [_new_uuids_key, _pending_uuids_key], argv: [message.uid])
        self
      end

      def to_s
        "subscriber:#{@subscription.subscriber} id:0x#{object_id.to_s(16)}"
      end

      def inspect
        "<#{self.class.name} #{self}>"
      end

      module ClassMethods
        def push(subscriptions, message)
          keys  = subscriptions.map { |sub|
            [ _new_uuids_key(sub), _payloads_key(sub) ]
          }.flatten
          _redis_lua_run(
            'push',
            keys: keys,
            argv: [keys.length/2, message.uid, message.payload])
          self
        end

        private

        def _payloads_key(subscription)
          "queue:data:#{subscription.subscriber}"
        end

        def _new_uuids_key(subscription)
          "queue:new:#{subscription.subscriber}"
        end

        def _pending_uuids_key(subscription)
          "queue:pending:#{subscription.subscriber}"
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

