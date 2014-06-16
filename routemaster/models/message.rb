require 'routemaster/models'
require 'routemaster/models/event'
require 'routemaster/mixins/log'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/bunny'

module Routemaster
  module Models
    # Abstracts a message received by RabbitMQ
    class Message
      include Routemaster::Mixins::Log
      include Routemaster::Mixins::Assert
      include Routemaster::Mixins::Bunny

      def initialize(delivery_info, properties, payload)
        @delivery_info = delivery_info
        @properties    = properties
        @payload       = payload
        @status        = nil
      end

      def kill?
        @payload == 'kill'
      end

      def ping?
        @payload == 'ping'
      end

      def event?
        !!event
      end

      def ack
        _assert(@status != :nack, 'message cannot be acked after being nacked')
        return if @delivery_info.nil? || @status
        bunny.ack(@delivery_info.delivery_tag, false)
        @status = :ack
        self
      end

      def nack
        _assert(@status != :ack, 'message cannot be nacked after being acked')
        return if @delivery_info.nil? || @status
        bunny.nack(@delivery_info.delivery_tag, false)
        @status = :nack
        self
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
