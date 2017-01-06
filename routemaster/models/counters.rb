require 'routemaster/models'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/log'
require 'core_ext/hash'
require 'monitor'
require 'msgpack'
require 'singleton'

module Routemaster
  module Models
    # Increments counters, with process-local buffering.
    class Counters
      include Singleton
      include Mixins::Redis
      include Mixins::Log


      def initialize
        @data = Hash.new(0).extend(MonitorMixin)
        @cv   = @data.new_cond
      end


      # Stops the buffering thread and flushes the buffer
      def finalize
        @data.synchronize do
          return self unless @running
          _log.info { 'finalizing counters buffer' }
          @running = false
          @cv.broadcast
        end
        @thread.join
        @thread = nil
        self
      end


      # Increment the counter for this `name` and `tags` by `count`, locally.
      # The local increments will be flushed to Redis regularly in another
      # thread.
      def incr(name, count: 1, **tags)
        _autostart
        @data.synchronize do
          @data[[name, tags]] += count
        end
        self
      end


      # Flush the counters in memory by incrementing persistent storage and
      # zero their in-memory value.
      # Counters that might otherwise overflow will be reset.
      def flush
        _log.debug { 'flushing counters buffer' }
        data = @data.synchronize { @data.dup.tap { @data.clear } }
        return self unless data.any?
        _redis_lua_run(
          'counters_flush',
          keys: [_key],
          argv: _serialize(data).flatten)
        self
      end


      # Return the current map of counters from the shared Redis store
      def dump
        _deserialize(_redis.hgetall(_key))
      end


      # Reset both the local and persisted counters
      def reset
        @data.synchronize do
          @data.clear
          _redis.del(_key)
        end
      end


      private


      def _autostart
        @data.synchronize do
          return if @running
          @running = true
        end
        @thread = Thread.new(&method(:_flusher_thread))
        Thread.pass
      end


      def _flusher_thread
        Thread.current.abort_on_exception = true
        while @running
          @data.synchronize { @cv.wait(_flush_interval) }
          flush
        end
        flush
      end


      def _serialize(data)
        {}.tap do |h|
          data.each_pair do |(name,options), v|
            k = MessagePack.dump([name, options.to_a.sort])
            h[k] = v
          end
        end
      end


      def _deserialize(data)
        Hash.new(0).tap do |result|
          data.each_pair do |f,v|
            name, tags = MessagePack.load(f)
            result[[name, Hash[tags].symbolize_keys]] = Integer(v)
          end
        end
      end


      def _field(name, options)
        MessagePack.dump([name, options.to_a.sort])
      end


      def _key
        'counters'
      end


      def _flush_interval
        ENV.fetch('ROUTEMASTER_COUNTER_FLUSH_INTERVAL').to_i
      end
    end
  end
end
