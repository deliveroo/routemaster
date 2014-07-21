require 'routemaster/models'
require 'bunny'
require 'singleton'

module Routemaster
  module Models
    # Wraps Bunny::Session with auto-reconnection
    class BunnyConnection
      include Singleton

      def method_missing(method, *args, &block)
        _connection.send(method, *args, &block)
      end

      def respond_to?(method, include_all = false)
        _connection.respond_to?(method, include_all)
      end
      
      private

      def _connection
        if @_connection && !@_connection.closed? && !@_connection.closing?
          @_connection
        else
          @_connection = Bunny.new(ENV['ROUTEMASTER_AMQP_URL']).start
        end
      end
    end
  end
end
