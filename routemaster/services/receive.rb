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
      include Routemaster::Mixins::Assert

      attr_reader :subscription

      def initialize(subscription, max_events)
        @batch        = Models::Batch.new
        @subscription = subscription
        @max_events   = max_events
        @consumer     = Models::Consumer.new(@subscription)
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
            message.ack
            raise KillError
          end

          if message.event?
            @batch.push(message)
            _deliver
          end
        end
      end


      def run_in
        age     = @batch.age
        timeout = @subscription.timeout

        if @last_count > 0 || age > timeout
          0
        else
          timeout - age
        end
      end

      private

      def _deliver
        @batch.synchronize do
          begin
            deliver = Routemaster::Services::Deliver.new(@subscription, @batch.events)
            @batch.ack if deliver.run
          rescue Routemaster::Services::Deliver::CantDeliver => e
            @batch.nack
            _log_exception(e)
          end
        end
      end
    end
  end
end
