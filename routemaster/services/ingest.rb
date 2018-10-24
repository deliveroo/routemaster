require 'routemaster/services'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/counters'
require 'routemaster/mixins/newrelic'
require 'routemaster/models/batch'
require 'routemaster/models/message'
require 'routemaster/models/job'


module Routemaster
  module Services
    # Enqueue an event for all topic subscribers and update statistics.

    class Ingest
      DEFAULT_PUBLISHER_TAG = 'null'.freeze
      MALFORMED_PUBLISHER_TAG = 'malformed'.freeze
      PUBLISHER_NAME_UUID_SEPARATOR = '--'.freeze

      include Mixins::Assert
      include Mixins::Counters
      include Mixins::Newrelic

      def initialize(options = {})
        @topic = options.fetch(:topic)
        @event = options.fetch(:event)
        _assert(@event.topic == @topic.name)
        @queue = options.fetch(:queue)
        @publisher = extract_publisher_name
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

              if batch.full?
                trace_with_newrelic('Custom/Services/queue-promote') do
                  @queue.promote(job)
                end
              end
            end
          end

          _counters.incr('events.published', topic: @topic.name, publisher: @publisher)
          _counters.incr('events.bytes', topic: @topic.name, count: data.length, publisher: @publisher)

          trace_with_newrelic('Custom/Services/topic-increment') do
            @topic.increment_count
          end
        end

        self
      end

      private

      def extract_publisher_name
        return DEFAULT_PUBLISHER_TAG unless @topic.publisher
        return MALFORMED_PUBLISHER_TAG unless @topic.publisher.include?(PUBLISHER_NAME_UUID_SEPARATOR)
        @topic.publisher.split(PUBLISHER_NAME_UUID_SEPARATOR).first
      end
    end
  end
end
