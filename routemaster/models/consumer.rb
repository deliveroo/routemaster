require 'routemaster/models'
require 'routemaster/models/event'
require 'routemaster/mixins/log'
require 'routemaster/mixins/bunny'
require 'routemaster/mixins/assert'

module Routemaster
  module Models
    # Abstracts a RabbitMQ consumer
    class Consumer
      include Routemaster::Mixins::Log
      include Routemaster::Mixins::Bunny
      include Routemaster::Mixins::Assert

      def initialize(subscription:, on_message:, on_cancel:)
        @subscription = subscription
        @on_message   = on_message
        @on_cancel    = on_cancel
        @running      = false
      end

      
      def run
        _log.info { "consumer for #{@subscription} starting" }
        _log.debug { "queue has #{@subscription.queue.message_count} messages" }
        @running = true
        @subscription.queue.subscribe(
          ack:               false,
          manual_ack:        true,
          block:             true,
          exclusive:         false,
          consumer_tag:      _key,
          on_cancellation:   method(:_on_cancellation).to_proc,
          &method(:_on_delivery).to_proc
        )
      rescue Exception => e
        _log_exception(e)
        # TODO: gracefully handle failing threads, possibly by sending myself
        # SIGQUIT.
        raise
      ensure
        @running = false
      end


      def cancel
        _log.info { "stopping consumer for #{@subscription}" }
        _assert(!!_consumer)
        _consumer.cancel
        sleep 10e-3 while @running
        _log.info { "consumer for #{@subscription} stopped" }
        self
      end

      def to_s
        "#{@subscription.subscriber} #{object_id.to_s(16)}"
      end

      def inspect
        "<#{self.class.name} #{self}>"
      end

      
      private

      def _consumer
        bunny.consumers[_key]
      end

      def _on_delivery(info, props, payload)
        _assert(@running, 'received a message while not consuming')
        @on_message.call Message.new(info, props, payload)
      end

      def _on_cancellation
        @on_cancel.call
      end

      def _key
        @@uid ||= 0
        @@uid += 1
        "#{@subscription.subscriber}-#{@uid}"
      end
    end
  end
end

