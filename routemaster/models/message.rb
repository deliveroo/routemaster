require 'routemaster/models'
require 'routemaster/models/event'
require 'routemaster/mixins/log'
require 'routemaster/mixins/assert'

module Routemaster
  module Models
    # Abstracts a message that transits on a queue
    class Message
      include Routemaster::Mixins::Log

      attr_reader :uid, :payload
      
      def initialize(payload, uid=nil)
        @uid     = uid || SecureRandom.uuid
        @payload = payload
        @status  = nil
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

      def inspect
        "<#{self.class.name} @uid=\"#{@uid}\">"
      end

      def event
        @event ||= begin
          Event.load(@payload)
        rescue ArgumentError, TypeError
          _log.warn 'bad event payload'
          nil
        rescue StandardError => e
          _log.error { 'unknown error while parsing event' }
          _log_exception(e)
          raise
        end
      end
    end
  end
end
