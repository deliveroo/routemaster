require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/models/queue'
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
        Models::Queue.push(@topic.subscribers, @event)
        @topic.increment_count
        self
      end
    end
  end
end
