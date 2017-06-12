require 'routemaster/services'
require 'routemaster/services/throttle'
require 'routemaster/mixins/log'
require 'routemaster/mixins/log_exception'
require 'routemaster/mixins/counters'
require 'routemaster/exceptions'
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

      def self.call(*args)
        new(*args).call
      end

      def initialize(subscriber, events, throttle_service: Services::Throttle)
        @subscriber = subscriber
        @buffer     = events
        @throttle   = throttle_service.new(@subscriber)
      end

      def call
        _log.debug { "starting delivery to '#{@subscriber.name}'" }

        error = nil
        start_at = Routemaster.now
        begin
          @throttle.check!(start_at)
          # send data
          response = _conn.post do |post|
            post.headers['Content-Type'] = 'application/json'
            post.body = Oj.dump(_data, mode: :compat)
          end

          unless response.success?
            @throttle.notice_failure
            error = Exceptions::CantDeliver.new("HTTP #{response.status}", @throttle.retry_backoff)
          end
        rescue Exceptions::EarlyThrottle => e
          error = e
        rescue Faraday::Error::ClientError => e
          @throttle.notice_failure
          error = Exceptions::CantDeliver.new("#{e.class.name}: #{e.message}", @throttle.retry_backoff)
        end

        elapsed = Routemaster.now - start_at
        status = error ? 'failure' : 'success'
        _update_counters(status, elapsed)
        
        if error
          _log.warn { "failed to deliver #{@buffer.length} events to '#{@subscriber.name}'" }
          raise error
        else
          @throttle.notice_success
          _log.debug { "delivered #{@buffer.length} events to '#{@subscriber.name}'" }
        end
        true
      end


      private


      # assemble data
      def _data
        @_data ||= @buffer.map do |event|
          {
            topic: event.topic,
            type:  event.type,
            url:   event.url,
            t:     event.timestamp
          }.tap { |d|
            d[:data] = event.data.to_hash if event.data
          }
        end
      end


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


      def _update_counters(status, t)
        _counters.incr('delivery.events',  queue: @subscriber.name, count: _data.length, status: status)
        _counters.incr('delivery.batches', queue: @subscriber.name, count: 1,            status: status)
        _counters.incr('delivery.time',    queue: @subscriber.name, count: t,            status: status)
        _counters.incr('delivery.time2',   queue: @subscriber.name, count: t*t,          status: status)
      end
    end
  end
end
