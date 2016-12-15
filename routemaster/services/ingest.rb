require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/models/batch'
require 'routemaster/models/message'

module Routemaster
  module Services
    # Enqueue an event for all topic subscribers, and
    # update statistics.
    class Ingest
      include Mixins::Assert

      def initialize(topic:, event:)
        _assert(event.topic == topic.name)
        @topic = topic
        @event = event
      end

      def call
        data = Services::Codec.new.dump(@event)
        @topic.subscribers.each do |s|
          batch = Models::Batch.ingest(data: data, timestamp: @event.timestamp, subscriber: s)

          begin
            batch.promote
          rescue Models::Batch::TransientError => e
            _log.warn { "failed to promote batch" }
            _log_exception(e)
          end
        end
        @topic.increment_count
        self
      end
    end
  end
end
