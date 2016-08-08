require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/models/consumer'
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
        message = Models::Message.new(@event.dump)
        Models::Consumer.push(@topic.subscribers, message)
        @topic.increment_count
        @topic.last_event = @event
        self
      end
    end
  end
end
