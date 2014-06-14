require 'routemaster/models'
require 'routemaster/models/event'
require 'routemaster/mixins/log'
require 'routemaster/mixins/bunny'

module Routemaster
  module Models
    # Abstracts a message received by RabbitMQ
    class Message
      include Routemaster::Mixins::Log
      include Routemaster::Mixins::Bunny

      def initialize(delivery_info, properties, payload)
        @delivery_info = delivery_info
        @properties    = properties
        @payload       = payload
      end

      def kill?
        @payload == 'kill'
      end

      def event?
        !!event
      end

      def ack
        return unless @delivery_info
        bunny.ack(@delivery_info.delivery_tag, false)
      end

      def nack
        return unless @delivery_info
        bunny.nack(@delivery_info.delivery_tag, false)
      end

      def event
        @event ||= begin
          Event.load(@payload)
        rescue ArgumentError, TypeError
          _log.warn 'bad event payload'
          ack
          nil
        rescue Exception => e
          _log.error { "unknown error while parsing event for #{@delivery_info.inspect}" }
          _log_exception(e)
          raise
        end
      end
    end
  end
end
