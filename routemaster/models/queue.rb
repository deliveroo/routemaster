require 'routemaster/models'
require 'routemaster/models/message'
require 'routemaster/mixins/log'
require 'routemaster/mixins/redis'
require 'routemaster/services/codec'

module Routemaster
  module Models
    # Abstraction for a queue.
    # Takes a Subscriber and allows to push Messages in and pull them out in
    # order.
    class Queue
      include Mixins::Log
      include Mixins::Redis

      attr_reader :subscriber

      def initialize(subscriber)
        @subscriber = subscriber
      end

      def pop
        uid, payload = _redis_lua_run(
          'pop',
          keys: [_new_uuids_key, _pending_uuids_key, _payloads_key],
          argv: [Routemaster.now])

        return if uid.nil?

        if payload.nil?
          _log.error { "missing payload for message #{uid} in queue #{@subscriber.name}" }
          return
        end

        Services::Codec.new.load(payload, uid)
      end

      def peek
        uid, payload = _redis_lua_run(
          'peek',
          keys: [_new_uuids_key, _payloads_key], 
          argv: [])

        return if uid.nil?

        if payload.nil?
          _log.error { "missing payload for message #{uid} in queue #{@subscriber.name}" }
          return
        end
        
        Services::Codec.new.load(payload, uid)
      end

      # Remove up to `count` oldest messages from the queue, and return the
      # count actually removed.
      def drop(count = 1)
        _redis_lua_run(
          'drop',
          keys: [_new_uuids_key, _payloads_key], 
          argv: [count]).to_i
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

      def length
        _redis.hlen(_payloads_key)
      end

      def staleness
        message = peek
        return 0 unless message
        Routemaster.now - message.timestamp
      end

      def to_s
        "subscriber:#{@subscriber.name} id:0x#{object_id.to_s(16)}"
      end

      def inspect
        "<#{self.class.name} #{self}>"
      end

      module ClassMethods
        def push(subscribers, message)
          payload = Services::Codec.new.dump(message)
          keys  = subscribers.flat_map { |sub|
            [ _new_uuids_key(sub), _payloads_key(sub) ]
          }
          _redis_lua_run(
            'push',
            keys: keys,
            argv: [keys.length/2, message.uid, payload])
          self
        end

        private

        def _payloads_key(subscriber)
          "queue:data:#{subscriber.name}"
        end

        def _new_uuids_key(subscriber)
          "queue:new:#{subscriber.name}"
        end

        def _pending_uuids_key(subscriber)
          "queue:pending:#{subscriber.name}"
        end
      end
      extend ClassMethods

      private

      %w[payloads new_uuids pending_uuids].each do |m|
        define_method "_#{m}_key" do
          self.class.send(__method__, @subscriber)
        end
      end
    end
  end
end

