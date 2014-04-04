require 'spec_helper'
require 'routemaster/services/fanout'
require 'routemaster/models/topic'
require 'routemaster/models/subscription'
require 'spec/support/persistence'

describe Routemaster::Services::Fanout do
  let(:topic)   { Routemaster::Models::Topic.new(name: 'widgets', publisher: 'alice') }
  let(:subscription)   { Routemaster::Models::Subscription.new(subscriber: 'bob') }
  let(:subscription2)  { Routemaster::Models::Subscription.new(subscriber: 'charlie') }
  let(:event)   { Routemaster::Models::Event.new(topic: 'widgets', type: 'noop', url: 'https://example.com/widgets/1') }
  let(:event2)  { Routemaster::Models::Event.new(topic: 'widgets', type: 'noop', url: 'https://example.com/widgets/2') }

  subject { described_class.new(topic) }

  describe '#initialize' do
    it 'fails without arguments' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end

    it 'passes with a topic' do
      expect { subject }.not_to raise_error
    end
  end
  
  describe '#run' do
    context 'without subscribers' do
      it 'removes events from the topic' do
        topic.push event
        expect(topic.peek).not_to be_nil

        subject.run
        expect(topic.peek).to be_nil
      end

      it 'works with multiple events' do
        10.times { topic.push event }
        10.times { subject.run }
        expect(topic.peek).to be_nil
      end
    end

    context 'with a single subscriber' do
      before { topic.subscribers.add subscription }

      it 'passes the event to the subscription' do
        topic.push event
        subject.run
        expect(topic.peek).to be_nil
        expect(subscription.peek).not_to be_nil
      end

      it 'preserves order' do
        topic.push event
        topic.push event2
        2.times { subject.run }
        expect(subscription.pop.url).to end_with('1')
        expect(subscription.pop.url).to end_with('2')
      end
    end

    context 'with multiple subscribers' do
      before do
        topic.subscribers.add subscription
        topic.subscribers.add subscription2
      end

      it 'fans out' do
        topic.push event
        subject.run
        expect(topic.pop).to be_nil
        expect(subscription.pop).not_to  be_nil
        expect(subscription2.pop).not_to be_nil
      end
    end
  end
end
