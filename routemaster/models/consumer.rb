require 'routemaster/models'
require 'routemaster/models/message'
require 'routemaster/mixins/log'
require 'routemaster/mixins/bunny'
require 'routemaster/mixins/assert'

module Routemaster
  module Models
    # Takes a Subscription and yields Messages,
    # thus abstracting the Bunny/RabbitMQ API.
    class Consumer
      include Routemaster::Mixins::Log
      include Routemaster::Mixins::Bunny
      include Routemaster::Mixins::Assert

      def initialize(subscription:, handler:)
        @subscription = subscription
        @handler      = handler
      end

      
      def start
        return if running?
        _log.info { "consumer for #{@subscription} starting" }
        _log.debug { "queue has #{@subscription.queue.message_count} messages" }
        @subscription.queue.subscribe(
          ack:               false,
          manual_ack:        true,
          block:             false,
          exclusive:         false,
          consumer_tag:      _key,
          on_cancellation:   method(:_on_cancellation).to_proc,
          &method(:_on_delivery).to_proc
        )
        _assert(running?, 'consumer not started?')
        self
      end

      def running?
        !!_consumer
      end

      def stop
        return self unless running?
        _log.info { "stopping consumer for #{@subscription}" }
        _consumer.cancel
        _log.info { "consumer for #{@subscription} stopped" }
        self
      end

      def to_s
        "subscriber:#{@subscription.subscriber} id:0x#{object_id.to_s(16)}"
      end

      def inspect
        "<#{self.class.name} #{self}>"
      end

      
      private

      def _consumer
        bunny.consumers[_key]
      end

      def _on_delivery(info, props, payload)
        _assert(running?, 'received a message while not consuming')
        @handler.on_message Message.new(info, props, payload)
      end

      def _on_cancellation(message)
        _log.warn "consumer #{self} cancelled remotely"
        @handler.on_cancel
      end

      def _key
        @_key ||= begin
          @@uid ||= 0
          @@uid += 1
          "#{@subscription.subscriber}-#{@@uid}"
        end
      end
    end
  end
end

