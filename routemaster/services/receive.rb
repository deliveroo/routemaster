require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/models/batch'
require 'routemaster/models/consumer'
require 'routemaster/services/deliver'

module Routemaster
  module Services
    # Passes batches of events from a Subscription to a Deliver service
    class Receive
      include Mixins::Log
      include Mixins::Assert

      attr_reader :subscription

      def initialize(subscription, max_events)
        @subscription = subscription
        @max_events   = max_events
        @consumer     = Models::Consumer.new(@subscription)
        @batch        = Models::Batch.new(@consumer)
        @last_count   = 1

        _assert(@max_events > 0)
        _log.debug { "initialized (max #{@max_events} events)" }
      end

      KillError = Class.new(StandardError)
      
      def run
        @last_count = @max_events.times do |count|
          message = @consumer.pop

          if message.nil?
            _deliver
            break count
          end
          
          if message && message.kill?
            _log.debug { 'received kill event' }
            @consumer.ack(message)
            raise KillError
          end

          if message.event?
            @batch.push(message)
            _deliver
          else
            @consumer.ack(message)
          end
        end
      end


      def time_to_next_run
        age     = @batch.age
        timeout = @subscription.timeout

        if @last_count > 0 || age > timeout
          0
        else
          timeout - age
        end
      end

      def batch_size
        @batch.events.length
      end

      private

      def _deliver
        @batch.synchronize do
          begin
            deliver = Deliver.new(@subscription, @batch.events)
            @batch.ack if deliver.run
          rescue Deliver::CantDeliver => e
            @batch.nack
            _log_exception(e)
          end
        end
      end
    end
  end
end
