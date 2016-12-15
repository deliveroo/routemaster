require 'routemaster/models'
require 'routemaster/models/message'
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

      attr_reader :uid

      def initialize(uid:, status:nil, worker_id:nil, deadline:nil, subscriber:nil)
        @status     = status
        @uid        = uid
        @worker_id  = worker_id
        @deadline   = deadline
        @subscriber = subscriber
      end

      def subscriber
        @subscriber ||=
        begin
          batch_key = "batch:#{@uid}"
          name = _redis.lindex(batch_key, 0)
          raise NonexistentError, @uid if name.nil?

          subscriber = Subscriber.find(name)
          raise NoSuchSubscriber, "batch=#{@uid}, subscriber=#{name}" if subscriber.nil?

          subscriber
        end
      end


      # Return the batch status, possibly inferring it from its UID's presence
      # in various data structure (memoised).
      #
      # Normally only useful while testing or validating data.
      def status
        @status ||= begin
          early_index_key = 'batches:early:by_deadline'
          ready_index_key = 'batches:ready:by_creation'
          pending_index_key = 'batches:pending'

          presence = _redis.multi {
            _redis.zscore(early_index_key, @uid)
            _redis.zscore(ready_index_key, @uid)
            _redis.hget(pending_index_key, @uid)
          }.map { |x| !!x }

          if presence.shift
            raise Inconsistency, "batch #{@uid} is in multiple sets" if presence.any?
            :early
          elsif presence.shift
            raise Inconsistency, "batch #{@uid} is in multiple sets" if presence.any?
            :ready
          elsif presence.pop
            :pending
          else
            raise Inconsistency, "batch #{@uid} is not in any status set"
          end
        end
      end


      # The working currently holding this batch (memoised)
      def worker_id 
        @worker_id ||= begin
          pending_index_key = 'batches:pending'
          _redis.hget(pending_index_key, @uid)
        end
      end


      # Return the number of events in the batch.
      def length
        batch_key = "batch:#{@uid}"
        raw = _redis.llen(batch_key)
        raise NonexistentError, @uid if raw.nil? || raw < 3
        raw - 3
      end

      # Is this the batch currently being filled for its subscriber?
      def current?
        batch_ref_key = "batches:early:by_subscriber:#{subscriber.name}"
        _redis.get(batch_ref_key) == @uid
      end


      # Number of times the batch ws nacked (memoised)
      def attempts
        @attempts ||= begin
          batch_key = "batch:#{@uid}"
          _redis.lindex(batch_key, 2).to_i
        end
      end

      
      # Returns the list of (serialised) payloads in the batch
      def data
        batch_key = "batch:#{@uid}"
        _redis.lrange(batch_key, 3, -1)
      end


      # Return a new instance without memoised state
      def reload
        self.class.new(uid: @uid)
      end


      # Transitions a batch from "early" to "ready" as appropriate (either full
      # or stale)
      def promote
        _assert(status == :early, 'Batch is not early')

        batch_key       = "batch:#{@uid}"
        batch_ref_key   = "batches:early:by_subscriber:#{subscriber.name}"
        early_index_key = 'batches:early:by_deadline'
        ready_queue_key = 'batches:ready:queue'
        ready_index_key = 'batches:ready:by_creation'
        now             = Routemaster.now

        watch = _redis.watch(batch_key, batch_ref_key) do
          current_deadline = _redis.zscore(early_index_key, @uid)
          current_size     = length
          current_ref      = _redis.get(batch_ref_key)

          raise NotEarlyError,    @uid if current_deadline.nil?
          raise NonexistentError, @uid if current_size.nil?

          unless current_deadline <= now || current_size >= subscriber.max_events
            _redis.unwatch
            return self
          end

          _log.debug { "promoting batch #{@uid} for #{subscriber.name}" }

          created_at = _redis.lindex(batch_key, 1)
          _redis.multi do
            _redis.lpush(ready_queue_key, @uid)
            _redis.zadd(ready_index_key, created_at, @uid)
            _redis.zrem(early_index_key, @uid)
            _redis.del(batch_ref_key) if current_ref == @uid
          end
        end

        throw :retry if watch.nil? # watch precondition failed
        # FIXME: limited retrying + monitoring
        
        @status = :ready
        self
      end


      # Removes all references to the batch (it's been delivered)
      def ack
        _assert(status == :pending, "Batch is not pending")

        batch_key = "batch:#{@uid}"
        pending_key = "batches:pending:#{@worker_id}"
        pending_index_key = "batches:pending"

        _redis.multi do |m|
          m.del(batch_key)
          m.lrem(pending_key, 0, @uid)
          m.hdel(pending_index_key, @uid)
        end

        @worker_id = nil
        @status = :acked
        self
      end


      # Move the batch back to the retry queue, with a incremented attempts
      # counter, and an exponentially backed-off deadline
      # (2^attempts seconds, capped at BACKOFF_LIMIT attempts).
      def nack
        _assert(status == :pending, "Batch is not pending")

        early_index_key = 'batches:early:by_deadline'
        pending_key = "batches:pending:#{@worker_id}"
        pending_index_key = "batches:pending"
        batch_key = "batch:#{@uid}"


        backoff = 1_000 * 2 ** [attempts, _backoff_limit].max
        deadline = Routemaster.now + backoff + rand(backoff)

        watch = _redis.watch(batch_key) do
          _redis.multi do
            _redis.lset(batch_key, 2, attempts+1)
            _redis.zadd(early_index_key, deadline, @uid)
            _redis.lrem(pending_key, 0, @uid)
            _redis.hdel(pending_index_key, @uid)
          end
        end

        throw :retry if watch.nil? # XXX

        @attempts = nil
        @worker_id = nil
        @status = :early
        self
      end


      module ClassMethods
        # Finds or creates a batch and appends the event to it.
        def ingest(data:, timestamp:, subscriber:)
          batch_ref_key = "batches:early:by_subscriber:#{subscriber.name}"
          early_index_key = 'batches:early:by_deadline'
          
          # data = Services::Codec.new.dump(event)
          deadline = timestamp + subscriber.timeout
          batch_uid = nil

          watch = _redis.watch(batch_ref_key) do
            items = [data]
            batch_uid = _redis.get(batch_ref_key)
            make_batch = !batch_uid
            
            if make_batch
              batch_uid = _generate_uid
              items.unshift(subscriber.name, Routemaster.now, 0)
            end

            batch_key = "batch:#{batch_uid}"
            _redis.multi do
              _redis.rpush(batch_key, items)
              if make_batch
                _redis.zadd(early_index_key, deadline, batch_uid)
                _redis.set(batch_ref_key, batch_uid)
              end
            end
          end

          throw :retry if watch.nil? # watch precondition failed
          # FIXME: limited retrying + monitoring
          
          new(status: :early, subscriber: subscriber, uid: batch_uid, deadline: deadline)
        end


        # Find one "early" batch that's actually stale, and promote it to "ready".
        def auto_promote
          early_index_key = 'batches:early:by_deadline'
          timestamp = Routemaster.now
          batch_uid, _ = _redis.zrangebyscore(early_index_key, '-inf', timestamp, limit: [0,1])
          return unless batch_uid
          new(status: :early, uid: batch_uid).promote
        rescue TransientError => e
          # XXX the batch_uid might have been auto-promoted in another thread -
          # retry
          _log.warn { "while auto-promoting: #{e.class.name}, #{e.message}" }
          nil
        end


        # Transition a batch from "ready" to "pending"
        def acquire(worker_id:)
          ready_queue_key = 'batches:ready:queue'
          ready_index_key = 'batches:ready:by_creation'
          pending_key     = "batches:pending:#{worker_id}"
          pending_index_key = 'batches:pending'

          if _redis.llen(pending_key) > 0
            raise "Worker '#{worker_id}' already has a batch acquired"
          end

          batch_uid, _ = _redis.brpoplpush(ready_queue_key, pending_key, timeout: _acquire_timeout)
          return if batch_uid.nil?

          # TODO: there's a write hole here. The ready index will need to be
          # culled regularly for batches that no longer exist; and the pending
          # index repopulated.
          
          _redis.multi do |m|
            m.hset(pending_index_key, batch_uid, worker_id)
            m.zrem(ready_index_key, batch_uid)
          end

          new(status: :pending, worker_id: worker_id, uid: batch_uid)
        end

        def all
          Iterator.new
        end

        private
        
        def _generate_uid
          SecureRandom.urlsafe_base64(15)
        end

        def _acquire_timeout
          @_acquire_timeout ||= Integer(ENV.fetch('ROUTEMASTER_ACQUIRE_TIMEOUT'))
        end

      end
      extend ClassMethods

      class Iterator
        include Enumerable
        include Mixins::Redis

        # Yied all know batches
        def each(batch_size:100)
          cursor = 0
          loop do
            cursor, keys = _redis.scan(cursor, match: 'batch:*', count: batch_size)
            keys.each do |k|
              uid = k.sub(/^batch:/, '')
              yield Batch.new(uid: uid)
            end
            break if Integer(cursor) == 0
          end
        end
      end

      private

      def _backoff_limit
        @_backoff_limit ||= Integer(ENV.fetch('ROUTEMASTER_BACKOFF_LIMIT'))
      end

    end
  end
end
