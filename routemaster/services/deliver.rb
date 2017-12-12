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

      def self.call(batch, events)
        new(batch: batch, events: events).call
      end

      def initialize(batch:, events:, throttle_service: Services::Throttle)
        @batch      = batch
        @buffer     = events
        @throttle   = throttle_service.new(batch.subscriber)
      end

      def call
        _log.debug { "starting delivery to '#{@batch.subscriber_name}'" }

        _, error = _with_counters { _with_throttle { _do_delivery } }
        
        if error
          _log.warn { "failed to deliver #{@buffer.length} events to '#{@batch.subscriber_name}'" }
          raise error
        else
          _log.info { "delivered #{@buffer.length} events to '#{@batch.subscriber_name}'" }
        end
        true
      end


      private

      # wrap a block in counters handling
      def _with_counters
        start_at = Routemaster.now
        latency = start_at - @batch.created_at
        _update_pre_counters(latency)
        yield.tap do |status, _error|
          elapsed = Routemaster.now - start_at
          _update_post_counters(status, elapsed, latency)
        end
      end

      # wrap block in a throttle check
      def _with_throttle
        @throttle.check!
        yield.tap do |status, _error|
          case status
          when 'failure' then @throttle.notice_failure
          when 'success' then @throttle.notice_success
          end
        end
      rescue Exceptions::EarlyThrottle => e
        ['throttled', e]
      end

      # return status and exception if any
      def _do_delivery
        # send data
        response = _conn.post do |post|
          post.headers['Content-Type'] = 'application/json'
          post.body = Oj.dump(_data, mode: :compat)
        end

        if response.success?
          ['success', nil]
        else
          error = Exceptions::CantDeliver.new("HTTP #{response.status}", @throttle.retry_backoff)
          ['failure', error]
        end
      rescue Faraday::Error::ClientError => e
        error = Exceptions::CantDeliver.new("#{e.class.name}: #{e.message}", @throttle.retry_backoff)
        ['failure', error]
      end


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
        @_conn ||= Faraday.new(@batch.subscriber.callback, ssl: { verify: _verify_ssl? }) do |c|
          c.adapter :typhoeus
          c.basic_auth(@batch.subscriber.uuid, 'x')
          c.options.open_timeout = CONNECT_TIMEOUT
          c.options.timeout      = TIMEOUT
        end
      end


      def _verify_ssl?
        !!( ENV.fetch('ROUTEMASTER_SSL_VERIFY') =~ /^(true|on|yes|1)$/i )
      end


      def _update_post_counters(status, delivery_time, latency)
        delivery_time2 = delivery_time * delivery_time
        _counters.incr('delivery.events',   queue: @batch.subscriber_name, count: _data.length,   status: status)
        _counters.incr('delivery.batches',  queue: @batch.subscriber_name, count: 1,              status: status)
        _counters.incr('delivery.time',     queue: @batch.subscriber_name, count: delivery_time,  status: status)
        _counters.incr('delivery.time2',    queue: @batch.subscriber_name, count: delivery_time2, status: status)
        _counters.incr('latency.batches.last_attempt', queue: @batch.subscriber_name, count: latency) if status == 'success'
      end

      def _update_pre_counters(latency)
        return unless @batch.attempts == 1
        _counters.incr('latency.batches.count',     queue: @batch.subscriber_name, count: 1)
        _counters.incr('latency.batches.first_attempt',  queue: @batch.subscriber_name, count: latency)
      end
    end
  end
end
