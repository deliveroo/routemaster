require 'routemaster/models'
require 'routemaster/models/message'
require 'routemaster/mixins/log'

module Routemaster
  module Models
    # Abstracts an ordered list of Message
    class Batch
      include Mixins::Log
      extend Forwardable

      def initialize(consumer)
        @consumer = consumer
        @batch = []
        @monitor = Monitor.new
      end

      delegate %i[push length] => :@batch

      def synchronize(&block)
        @monitor.synchronize { block.call(self) }
        self
      end

      def nack
        synchronize do
          @batch.each { |msg| @consumer.nack(msg) }
          _flush
        end
        self
      end

      def ack  
        synchronize do
          @batch.each { |msg| @consumer.ack(msg) }
          _flush
        end
        self
      end

      def events
        @batch.select { |m| m.kind_of?(Event) }
      end

      def age
        now = Routemaster.now
        @batch.map { |m| now - m.timestamp }.max || 0
      end

      private

      def _flush
        @batch.replace(Array.new)
      end

    end
  end
end
