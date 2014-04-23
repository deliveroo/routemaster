require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/bunny'
require 'routemaster/models/event'

# require the classes we may need to deserialize
# require 'routemaster/models/topic'
require 'routemaster/models/subscription'

# require the services we will perform
require 'routemaster/services/deliver'

module Routemaster::Services
  class Watch
    include Routemaster::Mixins::Log

    def initialize(max_events = nil)
      @max_events = max_events
      @consumers  = []
    end

    # TODO: reacting to new queues. Possibly with a kill message on an internal
    # transient queue.
    # TODO: stopping operation cleanly, possibly by trapping SIGTERM//SIGQUIT/SIGINT.
    # may be unnecessary given the acknowledgement mehanism.
    def run
      _log.info { 'starting watch service' }

      @consumers =
      Routemaster::Models::Subscription.map do |subscription|
        Consumer.new(subscription, @max_events).start
      end

      # in case there are no consumers, sentinel thread
      @thread = Thread.new { sleep(3_600) } if @consumers.empty?

      _log.debug { 'started watch service' }
      @consumers.each(&:wait)
      @thread.join if @thread
    end

    
    def stop
      _log.info { 'stopping watch service' }
      @consumers.each(&:stop)
      @thread.terminate if @thread
    end


    private


    class TaggedEvent < Struct.new(:event, :info)
      include Routemaster::Mixins::Bunny

      def ack
        bunny.ack(info.delivery_tag, false)
      end

      def nack
        bunny.nack(info.delivery_tag, false, true)
      end
    end


    class Consumer
      include Routemaster::Mixins::Bunny
      include Routemaster::Mixins::Log

      def initialize(sub, max_events)
        @batch        = []
        @subscription = sub
        @thread       = nil
        @max_events   = max_events # only for test purposes
        @counter      = 0
        @running      = false
        @consumer     = Bunny::Consumer.new(
          bunny,      # Bunny::Channel
          sub.queue,  # Bunny::Queue
          _key,       # consumer_tag
          false,      # no_ack
          false       # exclusive
        )
      end

      def start
        _log.info { "starting listener for #{@subscription}" }
        @consumer.on_delivery { |*args| _on_delivery(*args) }
        @consumer.on_cancellation { _on_cancellation }

        @thread = Thread.new do
          begin
            _log.debug { "queue has #{@subscription.queue.message_count} messages" }
            @running = true
            @subscription.queue.subscribe_with(@consumer, block: true)
          rescue Exception => e
            _log_exception(e)
            # TODO: gracefully handle failing threads, possibly by sending myself SIGQUIT.
            raise
          ensure
            @running = false
          end
          _log.info { "listen thread for #{@subscription} completing" }
        end
        @thread.abort_on_exception = true
        self
      end

      def wait
        return if @thread.nil?
        @thread.join
        @thread = nil
        self
      end

      def stop
        return if @thread.nil?
        _log.info { "stopping listener for #{@subscription}" }
        @consumer.cancel
        _on_cancellation # only gets called when remotely canceled?
        _lock.synchronize { @thread.terminate if @thread }
        wait
        self
      end

      private

      def _key
        @@uid ||= 0
        @@uid += 1
        "#{@subscription}.#{Socket.gethostname}.#{$$}.#{@@uid}"
      end

      def _on_delivery(delivery_info, properties, payload)
        _log.info { 'on_delivery starts' }
        
        if payload == 'kill'
          _log.debug { 'received kill event' }
          bunnny.ack(delivery_info.delivery_tag, false)
          stop
          abort 'thread should be dead!!'
        end

        begin 
          event = Routemaster::Models::Event.load(payload)
        rescue ArgumentError, TypeError
          _log.warn 'bad event payload'
          bunny.ack(delivery_info.delivery_tag, false)
          return
        rescue Exception => e
          _log.error { "unknown error while receiving event for #{delivery_info.inspect}" }
          _log_exception(e)
          return
        end
       
        @batch << TaggedEvent.new(event, delivery_info)
        _log.info 'before _deliver'
        _deliver
        _log.info 'after _deliver'

        @counter += 1
        stop if @max_events && @counter >= @max_events

        nil
      rescue Exception => e
        _log_exception(e)
      end

      def _on_cancellation
        _log.info { "cancelling #{@batch.length} pending events for #{@subscription}" }
        _lock.synchronize do
          @batch.each(&:nack)
          @batch.replace([])
        end
      end

      def _deliver
        _lock.synchronize do
          begin
            deliver = Routemaster::Services::Deliver.new(@subscription, @batch.map(&:event))
            if deliver.run
              @batch.each(&:ack)
              @batch.replace([])
            end
          rescue Routemaster::Services::Deliver::CantDeliver
            @batch.each(&:nack)
            # TODO: nack on delivery failrues
          end
        end
      end

      def _lock
        @_lock ||= Mutex.new
      end
    end
  end
end
