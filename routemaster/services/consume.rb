require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/models/batch'
require 'routemaster/models/consumer'

# require the services we will perform
require 'routemaster/services/deliver'

module Routemaster
  module Services

    class Consume
      include Routemaster::Mixins::Bunny
      include Routemaster::Mixins::Log

      def initialize(subscription, max_events)
        @batch        = Models::Batch.new
        @subscription = subscription
        @max_events   = max_events # only for test purposes
        @counter      = 0

        @consumer     = Models::Consumer.new(
          subscription: @subscription,
          on_message:   method(:_on_message).to_proc,
          on_cancel:    method(:_on_cancel).to_proc
        )
        _log.debug { 'initialized' }
      end

      def run
        @consumer.start
        self
      end

      def stop
        _log.info { 'stopping' }
        @consumer.cancel
        @batch.nack.flush
      end

      private


      def _on_message(message)
        _log.info { 'on_message starts' }
        
        if message.kill?
          _log.debug { 'received kill event' }
          message.ack
          stop
          return
        end

        if message.event?
          @batch.push(message)
          _log.info 'before _deliver'
          _deliver
          _log.info 'after _deliver'
        end

        @counter += 1
        if @max_events && @counter >= @max_events
          _log.debug { 'event allowance reached' }
          stop
        end

        nil
      rescue Exception => e
        _log_exception(e)
        stop
      end

      def _on_cancel
        _log.info { "cancelling #{@batch.length} pending events for #{@subscription}" }
        @batch.synchronize { |b| b.nack.flush }
      end

      def _deliver
        @batch.synchronize do
          begin
            deliver = Routemaster::Services::Deliver.new(@subscription, @batch.events)
            if deliver.run
              @batch.ack.flush
            # TODO:
            # else schedule delivery for later - using another thread?
            end
          rescue Routemaster::Services::Deliver::CantDeliver
            @batch.nack
            # TODO: nack on delivery failrues
          end
        end
      end
    end
  end
end
