require 'routemaster/models'
require 'singleton'
require 'bunny'

module Routemaster
  module Models
    class BunnyChannel
      include Singleton

      def method_missing(method, *args, &block)
        _channel.send(method, *args, &block)
      rescue Timeout::Error, Bunny::ConnectionClosedError
        attempts_left ||= 2
        raise if attempts_left < 1

        attempts_left -= 1
        disconnect
        retry
      end

      def respond_to?(method, include_all = false)
        _channel.respond_to?(method, include_all)
      end

      def disconnect
        @_connection.close if @_connection
        @_connection = nil
      end

      private

      def _channel
        if @_connection.nil? || @_connection.closed? || @_connection.closing?
          @_channel = nil
          @_connection = Bunny.new(
            ENV['ROUTEMASTER_AMQP_URL'],
            continuation_timeout: continuation_timeout
          ).start
        end

        if @_channel.nil? || @_channel.closed?
          @_channel = @_connection.create_channel
        end

        @_channel
      end

      def continuation_timeout
        ENV.fetch(
          'BUNNY_CONTINUATION_TIMEOUT',
          Bunny::Session::DEFAULT_CONTINUATION_TIMEOUT
        ).to_i
      end
    end
  end
end
