require 'routemaster/models'
require 'routemaster/models/message'
require 'routemaster/models/queue'
require 'routemaster/models/subscriber'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/log'
require 'routemaster/services/codec'
require 'wisper'

module Routemaster
  module Models
    # Abstracts an ordered list of Message
    class Batch
      include Mixins::Redis
      include Mixins::Assert
      include Mixins::Log
      include Wisper::Publisher

      Inconsistency    = Class.new(RuntimeError)

      # number of prefix metdata items in a batch list
      PREFIX_COUNT = 3


      attr_reader :uid, :deadline


      def initialize(uid:, deadline:nil, subscriber:nil)
        @uid        = uid
        @deadline   = deadline
        @subscriber = subscriber
      end


      def subscriber
        @subscriber ||= begin
          return if _subscriber_name.nil?
          Subscriber.find(_subscriber_name)
        end
      end


      # Return the number of events in the batch (memoised)
      def length
        @_length ||= begin
          raw = _redis.llen(_batch_key)
          return if raw.nil? || raw.zero?
          raise Inconsistency, @uid if raw < PREFIX_COUNT
          raw - PREFIX_COUNT
        end
      end


      # Does this batch still exist?
      def exists?
        _redis.exists(_batch_key)
      end


      def full?
        length && length >= subscriber.max_events
      end


      # Is this the batch currently being filled for its subscriber?
      def current?
        _batch_ref_key && _redis.get(_batch_ref_key) == @uid
      end


      # Counts the number of times delivery was attempted
      def attempts
        _redis.lindex(_batch_key, 2).to_i
      end


      # Increment the delivery attempts counter
      def fail
        _redis_lua_run(
          'batch_fail',
          keys: [_batch_key])
      end


      # Returns the list of (serialised) payloads in the batch
      # 
      # It is not an error if the batch no longer exists.
      def data
        _redis.lrange(_batch_key, PREFIX_COUNT, -1)
      end


      # Return a new instance without memoised state
      def reload
        self.class.new(uid: @uid)
      end


      def ==(other)
        other.kind_of?(Batch) && other.uid == @uid
      end


      # Transitions a batch from current.
      # A non-current batch will no have data added to it.
      # 
      # It is not an error if the batch is not current, or no longer exists.
      def promote
        _redis_lua_run(
          'batch_promote',
          keys: [_batch_ref_key],
          argv: [@uid])
        self
      end


      # Removes all references to the batch (it's been delivered, or autodropped)
      def delete
        count = _redis_lua_run(
          'batch_delete',
          keys: [_batch_key, _index_key, _batch_ref_key, _batch_counter_key, _event_counter_key],
          argv: [@uid, PREFIX_COUNT, _subscriber_name])
        broadcast(:events_removed, name: _subscriber_name, count: count)
        self
      end


      module ClassMethods
        include Wisper::Publisher

        # Add the data to the subscriber's current batch. A new batch will be
        # created as needed.
        def ingest(data:, timestamp:, subscriber:)
          batch_ref_key = _batch_ref_key(subscriber.name)
          now = Routemaster.now
          
          deadline = timestamp + subscriber.timeout
          batch_uid = nil

          watch = _redis.watch(batch_ref_key) do |w|
            items = [data]
            batch_uid = w.get(batch_ref_key)
            make_batch = !batch_uid
            
            if make_batch
              batch_uid = _generate_uid
              items.unshift(subscriber.name, now, 0)
            end

            batch_key = _batch_key(batch_uid)
            w.multi do |m|
              m.rpush(batch_key, items)
              if make_batch
                m.set(batch_ref_key, batch_uid)
                m.zadd(_index_key, now, batch_uid)
                m.hincrby(_batch_counter_key, subscriber.name, 1)
              end
              m.hincrby(_event_counter_key, subscriber.name, 1)
              # FIXME: convert this to Lua if possible.
            end
          end

          throw :retry if watch.nil? # watch precondition failed
          # FIXME: limited retrying + monitoring
          
          broadcast(:event_added, name: subscriber.name, count: 1)
          new(subscriber: subscriber, uid: batch_uid, deadline: deadline)
        end


        def counters
          # binding.pry
          {
            batches: _redis.hgetall(_batch_counter_key).map_values(&:to_i),
            events:  _redis.hgetall(_event_counter_key).map_values(&:to_i),
          }
        end


        def scrub
          # TODO:
          # iterate over all batches so the caller can enqueue them
        end


        def all
          Iterator.new
        end


        private

        def _generate_uid
          SecureRandom.urlsafe_base64(15)
        end


        def _batch_ref_key(name)
          name ? "batches:current:#{name}" : nil
        end

        def _event_counter_key
          'batches:counters:event'
        end

        def _batch_counter_key
          'batches:counters:batch'
        end

        def _index_key
          'batches:index'
        end

        def _batch_key(uid)
          "batch:#{uid}"
        end
      end
      extend ClassMethods


      private


      def _subscriber_name
        @_subscriber_name ||= _redis.lindex(_batch_key, 0)
      end


      def _batch_ref_key
        self.class.send(:_batch_ref_key, _subscriber_name)
      end


      def _batch_key
        self.class.send(:_batch_key, @uid)
      end

      extend Forwardable

      delegate %i[_index_key _event_counter_key _batch_counter_key] => :'self.class'


      class Iterator
        include Enumerable
        include Mixins::Redis

        def initialize(batch_size: 100)
          @batch_size = batch_size
        end

        # Yied all know batches, in creation order.
        def each
          _redis.zscan_each(Batch.send(:_index_key), count: @batch_size) do |uid, score|
            yield Batch.new(uid: uid, deadline: score)
          end
        end
      end

    end
  end
end
