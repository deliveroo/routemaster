require 'routemaster/services'
require 'routemaster/models/counters'
require 'wisper'

module Routemaster
  module Services
    # Listens for events and increments the corresponding metric counters
    class UpdateCounters
      include Singleton

      def setup
        Wisper.subscribe(self)
      end

      def auto_dropped_batch(name:, count:)
        _counters.incr('events.autodropped', queue: name, count: count)
      end

      def events_removed(name:, count:)
        _counters.incr('events.removed', queue: name, count: count)
      end

      def event_added(name:)
        _counters.incr('events.added', queue: name)
      end

      def delivery_failed(name:, count:)
        _counters.incr('delivery', status: :failure, queue: name, count: count)
      end

      def delivery_succeeded(name:, count:)
        _counters.incr('delivery', status: :success, queue: name, count: count)
      end

      def event_ingested(topic:)
        _counters.incr('events.published', topic: topic.name)
      end

      private

      def _counters
        Models::Counters.instance
      end
    end
  end
end
