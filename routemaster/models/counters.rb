require 'routemaster/models'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/log'
require 'monitor'
require 'msgpack'

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

      def finalize
        return unless @running
        _log.info { 'finalizing counters buffer' }
        @running = false
        @data.synchronize { @cv.broadcast }
        @thread.join
        @thread = nil
        nil
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
      # reset them.
      def flush
        data = @data.synchronize { @data.dup.tap { @data.clear } }
        data.keys.each do |k|
          data[_field(*k)] = data.delete(k)
        end
        _redis.pipelined do |p|
          data.each_pair do |field, count|
            p.hincrby(_key, field, count)
          end
        end
        self
      end

      # Return a list of counters from the shared Redis store, and clear it.
      # Each item is a triplet of name, tags, and counter value.
      def dump
        {}.tap do |result|
          data,_ = _redis.multi do |m|
            m.hgetall(_key)
            m.del(_key)
          end

          data.each_pair do |f,v|
            name, tags = MessagePack.load(f)
            result[[name, *tags]] = Integer(v)
          end
        end
      end


      private

      def _autostart
        return if @running
        @running  = true
        @thread = Thread.new(&method(:_flusher_thread))
        Thread.pass
      end

      def _flusher_thread
        Thread.current.abort_on_exception = true
        while @running
          @data.synchronize { @cv.wait(_flush_interval) }
          flush
        end
        _log.info { 'flushing counters buffer' }
        flush
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
