require 'spec_helper'
require 'spec/support/events'
require 'spec/support/persistence'
require 'routemaster/services/ingest'
require 'routemaster/models/subscriber'
require 'routemaster/models/subscription'
require 'routemaster/models/topic'

module Routemaster
  describe Services::Ingest do
    let(:topic) { Models::Topic.new(name: 'widgets', publisher: nil) }

    let(:subscribers) {[
      Models::Subscriber.new(name: 'foo'),
      Models::Subscriber.new(name: 'bar'),
      Models::Subscriber.new(name: 'qux').tap { |s| s.max_events = 2 },
    ]}

    let(:events) {[ make_event, make_event ]}

    let(:queue) { Models::Queue.new(name: 'main') }

    def perform
      events.each do |event|
        described_class.new(topic: topic, event: event, queue: queue).call
      end
    end

    before do
      Models::Subscription.new(topic: topic, subscriber: subscribers[0]).save
      Models::Subscription.new(topic: topic, subscriber: subscribers[2]).save
    end

    it 'pushes to all subscribers' do
      expect { perform }.to change {
        Models::Batch.all.map { |b| b.subscriber.name }.sort
      }.to eq %w[ foo qux ]
    end

    it 'pushes all events' do
      perform
      Models::Batch.all.each do |b|
        popped_events = b.data.map { |d| Services::Codec.new.load(d) }
        expect(popped_events).to eq(events)
      end
    end

    it 'increments the topic event count' do
      perform
      expect(topic.get_count).to eq(2)
    end

    it 'enqueues delivery jobs' do
      expect { perform }.to change { queue.length }.to(2)
    end


    it 'promotes delivery job if batch full' do
      perform
      expect(queue.dump.select { |j| j.run_at.nil? }).not_to be_empty
    end
  end
end
