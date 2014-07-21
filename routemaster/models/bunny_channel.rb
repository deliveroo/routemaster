require 'routemaster/models'
require 'singleton'
require 'bunny'

module Routemaster
  module Models
    class BunnyChannel
      include Singleton

      def method_missing(method, *args, &block)
        _channel.send(method, *args, &block)
      end

      def respond_to?(method, include_all = false)
        _channel.respond_to?(method, include_all)
      end

      def disconnect
        @_connection = nil
      end
      
      private

      def _channel
        if @_connection.nil? || @_connection.closed? || @_connection.closing?
          @_channel = nil
          @_connection = Bunny.new(ENV['ROUTEMASTER_AMQP_URL']).start
        end

        if @_channel.nil? || @_channel.closed?
          @_channel = @_connection.create_channel
        end

        @_channel
      end
    end
  end
end
