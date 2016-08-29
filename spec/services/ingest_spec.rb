require 'spec_helper'
require 'spec/support/events'
require 'spec/support/persistence'
require 'routemaster/services/ingest'
require 'routemaster/models/subscriber'
require 'routemaster/models/topic'

module Routemaster
  describe Services::Ingest do
    let(:topic) { Models::Topic.new(name: 'widgets', publisher: nil) }

    let(:subscribers) {[
      Models::Subscriber.new(name: 'foo'),
      Models::Subscriber.new(name: 'bar'),
      Models::Subscriber.new(name: 'qux'),
    ]}

    let(:consumers) {
      subscribers.map { |s| Models::Queue.new(s) }
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
      topic.subscribers.add subscribers[0]
      topic.subscribers.add subscribers[2]
    end

    it 'pushes to all subscribers' do
      perform
      expect(consumers[0].pop).to eq(events.first)
      expect(consumers[1].pop).to be_nil
      expect(consumers[2].pop).to eq(events.first)
    end

    it 'increments the topic event count' do
      perform
      expect(topic.get_count).to eq(2)
    end
  end
end
