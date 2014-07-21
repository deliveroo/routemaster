require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/models/batch'
require 'routemaster/models/consumer'
require 'routemaster/services/deliver'

module Routemaster
  module Services
    # Passes events in a Subscription to the Deliver service.
    class Receive
      include Routemaster::Mixins::Bunny
      include Routemaster::Mixins::Log


      def initialize(subscription, max_events)
        @batch        = Models::Batch.new
        @subscription = subscription
        @max_events   = max_events # only for test purposes
        @counter      = 0

        @consumer     = Models::Consumer.new(
          subscription: @subscription,
          handler:      self
        )
        _log.debug { 'initialized' }
      end


      def start
        @consumer.start
        self
      end


      def stop
        _log.info { 'stopping' }
        @consumer.stop
        on_cancel
        self
      end


      def running?
        @consumer.running?
      end


      def on_message(message)
        _log.info { 'on_message starts' }
        
        if message.kill?
          _log.debug { 'received kill event' }
          message.ack
          stop
          return
        end

        if message.event?
          @batch.push(message)
          _deliver
        end

        @counter += 1
        if @max_events && @counter >= @max_events
          _log.debug { 'event allowance reached' }
          stop
        end

        nil
      rescue StandardError => e
        _log_exception(e)
        stop
      end


      def on_cancel
        _log.info { "cancelling #{@batch.length} pending events for #{@subscription}" }
        @batch.nack
      end


      private


      def _deliver
        @batch.synchronize do
          begin
            deliver = Routemaster::Services::Deliver.new(@subscription, @batch.events)
            if deliver.run
              @batch.ack
            # TODO:
            # else schedule delivery for later - using another thread?
            end
          rescue Routemaster::Services::Deliver::CantDeliver => e
            @batch.nack
            _log_exception(e)
          end
        end
      end
    end
  end
end
