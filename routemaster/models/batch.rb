require 'routemaster/models'
require 'routemaster/models/message'
require 'routemaster/models/queue'
require 'routemaster/models/subscriber'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/log'
require 'routemaster/mixins/counters'
require 'routemaster/services/codec'

module Routemaster
  module Models
    # Abstracts an ordered list of Message
    class Batch
      include Mixins::Redis
      include Mixins::Assert
      include Mixins::Log
      include Mixins::Counters

      Inconsistency    = Class.new(RuntimeError)

      # number of prefix metdata items in a batch list
      PREFIX_COUNT = 3


      attr_reader :uid, :deadline


      def initialize(uid:, deadline: nil, subscriber: nil)
        @uid        = uid
        @deadline   = deadline
        @subscriber = subscriber
      end


      def subscriber
        @subscriber ||= begin
          return if subscriber_name.nil?
          Subscriber.find(subscriber_name)
        end
      end

      def subscriber_name
        @subscriber_name ||= _redis.lindex(_batch_key, 0)
      end


      # Return the number of events in the batch (memoised)
      def length
        @_length ||= begin
          raw = _redis.llen(_batch_key)
          return 0 if raw.nil? || raw.zero?
          raise Inconsistency, @uid if raw < PREFIX_COUNT
          raw - PREFIX_COUNT
        end
      end


      # Does this batch still exist?
      def exists?
        _redis.exists(_batch_key)
      end


      # Is this batch deliverable?
      def valid?
        subscriber && data&.any?
      end


      # Has the batch reached capacity?
      def full?
        length && subscriber && length >= subscriber.max_events
      end


      # Is this the batch currently being filled for its subscriber?
      def current?
        _redis.sismember(_batch_ref_key, @uid)
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


      # Returns the list of (serialised) payloads in the batch.
      # Memoised.
      # 
      # It is not an error if the batch no longer exists.
      def data
        @_data ||= _redis.lrange(_batch_key, PREFIX_COUNT, -1)
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
          keys: [_batch_key, _index_key, _batch_ref_key, _batch_gauge_key, _event_gauge_key],
          argv: [@uid, PREFIX_COUNT, subscriber_name])
        _counters.incr('events.removed', queue: subscriber_name, count: count)
        self
      end


      module ClassMethods
        include Mixins::Counters

        # Add the data to the subscriber's current batch. A new batch will be
        # created as needed. The batch will be promoted if it's full.
        def ingest(data:, timestamp:, subscriber:)
          batch_ref_key = _batch_ref_key(subscriber.name)
          now           = Routemaster.now
          deadline      = timestamp + subscriber.timeout

          # Ingestion might create a new batch if there is no current batch (pointed to by
          # `batch_ref_key`) changes between the SRANDMEMBER and the EVAL.
          # To this effect, we provide an alternate batch UID to be used if
          # creating a batch.
          uid = _redis.srandmember(batch_ref_key)
          alt_uid = _generate_uid

          yield if block_given? # this is used in tests only, to inject behaviour to simulate concurrency

          actual_uid =  _redis_lua_run(
              'batch_ingest',
              keys: [batch_ref_key, _batch_key(uid), _batch_key(alt_uid), _index_key, _batch_gauge_key, _event_gauge_key],
              argv: [uid, alt_uid, data, subscriber.name, PREFIX_COUNT, subscriber.max_events, now])
          
          _counters.incr('events.added', queue: subscriber.name)
          new(subscriber: subscriber, uid: actual_uid, deadline: deadline)
        end


        def gauges
          {
            batches: _redis.hgetall(_batch_gauge_key).map_values(&:to_i).tap { |h| h.default = 0 },
            events:  _redis.hgetall(_event_gauge_key).map_values(&:to_i).tap { |h| h.default = 0 },
          }
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

        def _event_gauge_key
          'batches:gauges:event'
        end

        def _batch_gauge_key
          'batches:gauges:batch'
        end

        def _index_key
          'batches:index'
        end

        def _batch_key(uid)
          uid ? "batches:#{uid}" : nil
        end
      end
      extend ClassMethods


      private


      def _batch_ref_key
        self.class.send(:_batch_ref_key, subscriber_name)
      end


      def _batch_key
        self.class.send(:_batch_key, @uid)
      end

      def _class_method_delegate(*args)
        self.class.send(__callee__, *args)
      end

      alias_method :_index_key,       :_class_method_delegate
      alias_method :_event_gauge_key, :_class_method_delegate
      alias_method :_batch_gauge_key, :_class_method_delegate


      class Iterator
        include Enumerable
        include Mixins::Redis

        def initialize(batch_size: 100)
          @batch_size = batch_size
        end

        # Yields all know batches, in creation order.
        def each
          _redis.zscan_each(Batch.send(:_index_key), count: @batch_size) do |uid, score|
            yield Batch.new(uid: uid, deadline: score)
          end
        end
      end

    end
  end
end
