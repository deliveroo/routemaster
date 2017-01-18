require 'routemaster/services'
require 'routemaster/mixins/log'
require 'routemaster/mixins/log_exception'
require 'routemaster/mixins/counters'
require 'faraday'
require 'typhoeus'
require 'typhoeus/adapters/faraday'
require 'json'
require 'oj'

module Routemaster
  module Services
    # Manage delivery buffer and emitting the HTTP delivery
    class Deliver
      include Mixins::Log
      include Mixins::LogException
      include Mixins::Counters

      CONNECT_TIMEOUT = ENV.fetch('ROUTEMASTER_CONNECT_TIMEOUT').to_i
      TIMEOUT         = ENV.fetch('ROUTEMASTER_TIMEOUT').to_i

      CantDeliver = Class.new(StandardError)

      def self.call(*args)
        new(*args).call
      end

      def initialize(subscriber, events)
        @subscriber = subscriber
        @buffer     = events
      end

      def call
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
            post.body = Oj.dump(data, mode: :compat)
          end
          raise "HTTP #{response.status}" unless response.success?
        rescue RuntimeError, Faraday::Error::ClientError => e
          _log.warn { "failed to deliver #{@buffer.length} events to '#{@subscriber.name}'" }
          _counters.incr('delivery', queue: @subscriber.name, count: data.length, status: 'failure')
          raise CantDeliver.new("#{e.class.name}: #{e.message}")
        end

        _log.debug { "delivered #{@buffer.length} events to '#{@subscriber.name}'" }
        _counters.incr('delivery', queue: @subscriber.name, count: data.length, status: 'success')
        true
      end


      private


      def _conn
        @_conn ||= Faraday.new(@subscriber.callback, ssl: { verify: _verify_ssl? }) do |c|
          c.adapter :typhoeus
          c.basic_auth(@subscriber.uuid, 'x')
          c.options.open_timeout = CONNECT_TIMEOUT
          c.options.timeout      = TIMEOUT
        end
      end

      def _verify_ssl?
        !!( ENV.fetch('ROUTEMASTER_SSL_VERIFY') =~ /^(true|on|yes|1)$/i )
      end
    end
  end
end
