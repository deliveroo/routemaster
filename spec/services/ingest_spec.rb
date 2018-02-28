require 'spec_helper'
require 'spec/support/events'
require 'spec/support/persistence'
require 'spec/support/counters'
require 'routemaster/services/ingest'
require 'routemaster/models/subscriber'
require 'routemaster/models/subscription'
require 'routemaster/models/topic'

module Routemaster
  describe Services::Ingest do
    let(:topic) { Models::Topic.find_or_create!(name: 'widgets', publisher: nil) }

    let(:subscribers) {[
      Models::Subscriber.new(name: 'foo').save,
      Models::Subscriber.new(name: 'bar').save,
      Models::Subscriber.new(name: 'qux').tap { |s| s.max_events = 2 }.save,
    ]}

    let(:events) {[ make_event, make_event ]}

    let(:queue) { Models::Queue::MAIN }

    let(:perform) do
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
      expect(queue.jobs.select { |j| j.run_at.nil? }).not_to be_empty
    end

    it 'promotes batch job if batch full' do
      perform
      batch = Models::Batch.all.find { |b| b.subscriber.name == 'qux' }
      expect(batch).not_to be_current
    end

    it 'increments events.published' do
      expect { perform }.to change { get_counter('events.published', topic: 'widgets') }.from(0).to(2)
    end

    it 'increments events.bytes' do
      expect { perform }.to change { get_counter('events.bytes', topic: 'widgets') }.from(0)
    end

    context 'when a specific subscriber is specified' do
      let(:subscriber_name) { 'foo' }
      let(:perform) do
        events.each do |event|
          described_class.new(topic: topic, event: event, queue: queue, subscriber_name: subscriber_name).call
        end
      end

      it 'pushes to only that one subscriber' do
        expect { perform }.to change {
          Models::Batch.all.map { |b| b.subscriber.name }.sort
        }.to eq %w[ foo ]
      end

      context 'when the subscriber with the given name is not subscribed to the topic' do
        let(:subscriber_name) { 'bar' }

        it 'fails with relevant error' do
          expect { perform }.to raise_error(ArgumentError)
            .with_message 'Subscriber not subscribed to topic'
        end
      end

      context 'when the subscriber with the given name does not exist' do
        let(:subscriber_name) { 'poo' }

        it 'fails with relevant error' do
          expect { perform }.to raise_error(ArgumentError)
            .with_message 'Subscriber not found'
        end
      end

    end
  end
end
