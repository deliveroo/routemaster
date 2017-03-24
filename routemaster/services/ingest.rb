require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/counters'
require 'routemaster/models/batch'
require 'routemaster/models/message'
require 'routemaster/models/job'

module Routemaster
  module Services
    # Enqueue an event for all topic subscribers, and
    # update statistics.
    class Ingest
      include Mixins::Assert
      include Mixins::Counters

      def initialize(topic:, event:, queue:)
        _assert(event.topic == topic.name)
        @topic = topic
        @event = event
        @queue = queue
      end

      def call
        data = Services::Codec.new.dump(@event)
        @topic.subscribers.each do |s|
          batch = Models::Batch.ingest(data: data, timestamp: @event.timestamp, subscriber: s)

          job = Models::Job.new(name: 'batch', args: batch.uid, run_at: batch.deadline)
          @queue.push(job)
          @queue.promote(job) if batch.full?
        end

        _counters.incr('events.published', topic: @topic.name)
        _counters.incr('events.bytes', topic: @topic.name, count: data.length)
        @topic.increment_count
        self
      end
    end
  end
end
