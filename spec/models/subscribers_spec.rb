require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/subscribers'
require 'routemaster/models/subscription'

describe Routemaster::Models::Subscribers do
  Subscription = Routemaster::Models::Subscription

  let(:exchange) { double 'exchange' }
  let(:topic) { double 'Topic', name: 'widgets', exchange: exchange }
  subject { described_class.new(topic) }

  let(:queue) { double 'queue', bind: true }

  before do
    allow_any_instance_of(Subscription).to receive(:queue).and_return(queue)
  end

  describe '#initialize' do
    it 'passes' do
      expect { subject }.not_to raise_error
    end
  end

  describe '#to_a' do
    it 'returns an array' do
      expect(subject.to_a).to be_a_kind_of(Array)
    end
  end

  describe '#each' do
    it 'yields subscriptions' do
      subject.add Subscription.new(subscriber: 'bob')
      expect { |b| subject.each(&b) }.to yield_with_args(Subscription)
    end
  end

  describe '#add' do
    it 'adds the subscriber' do
      subject.add Subscription.new(subscriber: 'bob')
      expect(subject.first.subscriber).to eq('bob')
    end

    it 'behaves like a set' do
      subject.add Subscription.new(subscriber: 'alice')
      subject.add Subscription.new(subscriber: 'bob')
      subject.add Subscription.new(subscriber: 'alice')
      expect(subject.count).to eq(2)
    end

    it 'binds the queue to the exchange' do
      expect(queue).to receive(:bind).with(exchange)
      subject.add Subscription.new(subscriber: 'alice')
    end
  end
end

