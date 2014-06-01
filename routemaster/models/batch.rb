require 'routemaster/models'
require 'routemaster/models/message'
require 'routemaster/mixins/log'
require 'routemaster/mixins/bunny'

module Routemaster
  module Models
    # Abstracts an ordered list of Message
    class Batch
      include Routemaster::Mixins::Log
      extend Forwardable

      def initialize
        @batch = []
        @mutex = Mutex.new
      end

      delegate %i[push length] => :@batch

      def synchronize(&block)
        if @mutex.owned?
          block.call(self)
        else
          @mutex.synchronize { block.call(self) }
        end
        self
      end

      def nack
        synchronize do
          @batch.each(&:nack)
          _flush
        end
        self
      end

      def ack  
        synchronize do
          @batch.each(&:ack)
          _flush
        end
        self
      end

      def events
        @batch.map(&:event)
      end

      private

      def _flush
        @batch.replace(Array.new)
      end

    end
  end
end
