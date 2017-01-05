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

      def initialize(id: nil, queue: nil)
        @id = id || SecureRandom.urlsafe_base64(15)
        @queue = queue
      end

      # Acquires a job for delivery (blocking), and run it
      def call
        _redis.hset(_index_key, @id, Routemaster.now)

        @queue.pop(@id) do |job|
          _log.debug { "running job '#{job.name}' with args #{job.args.inspect}" }
          job.perform
        end
        nil
      end

      def cleanup
        _redis.hdel(_index_key, @id)
      end

      def last_at
        raw = _redis.hget(_index_key, @id)
        return if raw.nil?
        Integer(raw)
      end

      def ==(other)
        other.kind_of?(self.class) && other.id == @id
      end

      def self.each
        _redis.hkeys('workers').each do |id|
          yield new(id: id)
        end
      end

      private

      def _index_key
        'workers'
      end
    end
  end
end
