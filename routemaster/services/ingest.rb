require 'routemaster/services'
require 'routemaster/models/topic'

module Routemaster::Services
  # Enqueue an event for all topic subscribers, and
  # update statistics.
  class Ingest
    def initialize(event:)
      @event = event
    end

    def call
      topic = Models::Topic.find(@event.topic)
      consumers = _topic.subscribers.map { |s| Models::Consumer.new(s) }
      message = Message.new(@event.dump)
      Models::Consumer.push(consumers, message)
      self
    end
  end
end

