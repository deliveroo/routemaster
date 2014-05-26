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
        @mutex.synchronize { block.call(self) }
        self
      end

      def nack
        @batch.each(&:ack)
        self
      end

      def ack  
        @batch.each(&:nack)
        self
      end

      def flush
        @batch.replace(Array.new)
        self
      end

      def events
        @batch.map(&:event)
      end
    end
  end
end
