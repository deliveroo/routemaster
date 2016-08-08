require 'spec_helper'
require 'spec/support/events'
require 'spec/support/persistence'
require 'routemaster/services/ingest'
require 'routemaster/models/subscription'
require 'routemaster/models/topic'

module Routemaster
  describe Services::Ingest do
    let(:topic) { Models::Topic.new(name: 'widgets', publisher: nil) }

    let(:subscriptions) {[
      Models::Subscription.new(subscriber: 'foo'),
      Models::Subscription.new(subscriber: 'bar'),
      Models::Subscription.new(subscriber: 'qux'),
    ]}

    let(:consumers) {
      subscriptions.map { |s| Models::Consumer.new(s) }
    }

    let(:events) {[
      make_event, make_event
    ]}

    def perform
      events.each do |event|
        described_class.new(topic: topic, event: event).call
      end
    end

    before do
      topic.subscribers.add subscriptions[0]
      topic.subscribers.add subscriptions[2]
    end

    it 'pushes to all subscribers' do
      perform
      expect(consumers[0].pop&.event).to eq(events.first)
      expect(consumers[1].pop&.event).to be_nil
      expect(consumers[2].pop&.event).to eq(events.first)
    end

    it 'increments the topic event count' do
      perform
      expect(topic.get_count).to eq(2)
    end

    it 'saves the latest event' do
      perform
      expect(topic.last_event).to eq(events.last)
    end
  end
end
