require 'routemaster/services'
require 'routemaster/mixins/log_exception'
require 'routemaster/services/deliver'
require 'routemaster/services/codec'
require 'routemaster/models/event'
require 'routemaster/models/batch'

module Routemaster
  module Services
    class Worker
      include Mixins::Log
      include Mixins::LogException
      include Mixins::Redis

      attr_reader :id

      def initialize(id: nil, delivery: Services::Deliver)
        @id = id || SecureRandom.urlsafe_base64(15)
        @delivery = delivery
      end

      # Acquires a batch for delivery (blocking), and deliver it
      def call
        _redis.hset(_index_key, @id, Routemaster.now)

        batch = Models::Batch.acquire(worker_id: @id)
        return false unless batch
        _log.debug { "worker.#{@id}: acquired batch #{batch.uid}" }

        events = batch.data.
          map { |d| Services::Codec.new.load(d) }.
          select { |msg| msg.kind_of?(Models::Event) }

        begin
          @delivery.call(batch.subscriber, events)
          batch.ack
          true
        rescue Services::Deliver::CantDeliver => e
          batch.nack
          _log_exception(e)
          false
        end
      end

      def cleanup
        _redis.hdel(_index_key, @id)
      end

      def last_at
        raw = _redis.hget(_index_key, @id)
        return if raw.nil?
        Integer(raw)
      end

      private

      def _index_key
        'workers'
      end
    end
  end
end
