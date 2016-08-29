require 'routemaster/services'
require 'routemaster/mixins/log'
require 'routemaster/mixins/log_exception'
require 'config/openssl'
require 'faraday'
require 'json'

module Routemaster
  module Services
    # Manage delivery buffer and emitting the HTTP delivery
    class Deliver
      include Mixins::Log
      include Mixins::LogException

      CantDeliver = Class.new(Exception)

      def initialize(subscriber, events)
        @subscriber = subscriber
        @buffer       = events
      end

      def run
        return false unless @buffer.any?
        return false unless _should_deliver?(@buffer)
        _log.debug { "starting delivery to '#{@subscriber.name}'" }


        # assemble data
        data = @buffer.map do |event|
          {
            topic: event.topic,
            type:  event.type,
            url:   event.url,
            t:     event.timestamp
          }
        end

        # send data
        begin
          response = _conn.post do |post|
            post.headers['Content-Type'] = 'application/json'
            post.body = data.to_json
          end
        rescue Faraday::Error::ClientError => e
          raise CantDeliver.new("delivery failure (#{e.class.name}: #{e.message})")
        end

        if response.success?
          _log.debug { "delivered #{@buffer.length} events to '#{@subscriber.name}'" }
          return true
        end

        _log.warn { "failed to deliver #{@buffer.length} events to '#{@subscriber.name}'" }
        raise CantDeliver.new("delivery failure (HTTP #{response.status})")
      end


      private


      def _should_deliver?(buffer)
        return true  if buffer.first.timestamp + @subscriber.timeout <= Routemaster.now
        return false if buffer.length == 0
        return true  if buffer.length >= @subscriber.max_events
        false
      end


      def _conn
        @_conn ||= Faraday.new(@subscriber.callback) do |c|
          c.adapter Faraday.default_adapter
          c.basic_auth(@subscriber.uuid, 'x')
        end
      end
    end
  end
end
