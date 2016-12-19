require 'routemaster/models'
require 'routemaster/models/message'
require 'routemaster/models/queue'
require 'routemaster/models/subscriber'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/log'
require 'routemaster/services/codec'

module Routemaster
  module Models
    # Abstracts an ordered list of Message
    class Batch
      include Mixins::Redis
      include Mixins::Assert
      include Mixins::Log

      TransientError   = Class.new(StandardError)
      NotEarlyError    = Class.new(TransientError)
      NonexistentError = Class.new(TransientError)
      NoSuchSubscriber = Class.new(TransientError)
      Inconsistency    = Class.new(RuntimeError)

      attr_reader :uid, :deadline

      def initialize(uid:, deadline:nil, subscriber:nil)
        @uid        = uid
        @deadline   = deadline
        @subscriber = subscriber
      end


      def subscriber
        @subscriber ||= begin
          name = _redis.lindex(_batch_key, 0)
          return if name.nil?

          subscriber = Subscriber.find(name)
          raise NoSuchSubscriber, "batch=#{@uid}, subscriber=#{name}" if subscriber.nil?

          subscriber
        end
      end


      # Return the number of events in the batch.
      def length
        raw = _redis.llen(_batch_key)
        raise NonexistentError, @uid if raw.nil? || raw < 3
        raw - 3
      end


      # Does this batch still exist?
      def exists?
        _redis.exists(_batch_key)
      end


      def full?
        length >= subscriber.max_events
      rescue NonexistentError, NoSuchSubscriber
        nil
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
        _redis.lrange(_batch_key, 3, -1)
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
        _redis.watch(_batch_key, _batch_ref_key) do |w|
          if _batch_ref_key.nil?
            w.unwatch
            return self
          end

          uid = _redis.get(_batch_ref_key)
          w.multi do |m|
            m.del(_batch_ref_key) if @uid == uid
          end
        end
        # FIXME:
        # retry watch
        self
      end


      # Removes all references to the batch (it's been delivered)
      def delete
        _assert(!current?, "Cannot delete the current batch")

        _redis.multi do |m|
          m.del(_batch_key)
          m.zrem(_index_key, @uid)
        end
        self
      end

      module ClassMethods
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
              end
              # FIXME: convert this to Lua if possible.
            end
          end

          throw :retry if watch.nil? # watch precondition failed
          # FIXME: limited retrying + monitoring
          
          new(subscriber: subscriber, uid: batch_uid, deadline: deadline)
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

        def _index_key
          'batches:index'
        end

        def _batch_key(uid)
          "batch:#{uid}"
        end
      end
      extend ClassMethods


      private


      def _batch_ref_key
        self.class.send(:_batch_ref_key, subscriber&.name)
      end


      def _index_key
        self.class.send(:_index_key)
      end

      def _batch_key
        self.class.send(:_batch_key, @uid)
      end


      class Iterator
        include Enumerable
        include Mixins::Redis

        # Yied all know batches, in creation order.
        def each(batch_size:100)
          _redis.zscan_each(Batch.send(:_index_key), count: batch_size) do |uid, score|
            yield Batch.new(uid: uid, deadline: score)
          end
        end
      end

    end
  end
end
