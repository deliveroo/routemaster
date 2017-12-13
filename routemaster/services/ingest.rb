require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/counters'
require 'routemaster/mixins/newrelic'
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
      include Mixins::Newrelic

      def initialize(topic:, event:, queue:)
        _assert(event.topic == topic.name)
        @topic = topic
        @event = event
        @queue = queue
      end

      def call
        trace_with_newrelic('Custom/Services/ingest') do
          data = Services::Codec.new.dump(@event)
          @topic.subscribers.each do |s|
            trace_with_newrelic("Custom/Services/ingest-#{s.name}") do
              batch = nil

              trace_with_newrelic('Custom/Services/batch-ingest') do
                batch = Models::Batch.ingest(data: data, timestamp: @event.timestamp, subscriber: s)
              end

              job = Models::Job.new(name: 'batch', args: batch.uid, run_at: batch.deadline)

              trace_with_newrelic('Custom/Services/queue-push') do
                @queue.push(job)
              end

              trace_with_newrelic('Custom/Services/queue-promote') do
                @queue.promote(job) if batch.full?
              end
            end
          end

          _counters.incr('events.published', topic: @topic.name)
          _counters.incr('events.bytes', topic: @topic.name, count: data.length)

          trace_with_newrelic('Custom/Services/topic-increment') do
            @topic.increment_count
          end
        end

        self
      end
    end
  end
end
