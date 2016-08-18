require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/subscribers'
require 'routemaster/models/subscription'

describe Routemaster::Models::Subscribers do
  Subscription = Routemaster::Models::Subscription

  let(:topic) { double 'Topic', name: 'widgets' }
  subject { described_class.new(topic) }

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
      expect(subject.count).to eq(1)
      expect(subject.first).to be_a_kind_of(Subscription)
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
  end

  describe '#remove' do
    before do
      subject.add Subscription.new(subscriber: 'alice')
      subject.add Subscription.new(subscriber: 'bob')
    end

    it 'removes the subscriber' do
      expect {
        subject.remove Subscription.new(subscriber: 'bob')
      }.to change {
        subject.map(&:subscriber).sort
      }.from(
        %w[alice bob]
      ).to (
        %w[alice]
      )
    end

    it 'works if absent' do
      expect {
        subject.remove Subscription.new(subscriber: 'charlie')
      }.not_to change {
        subject.map(&:subscriber).sort
      }
    end
  end

  describe '#replace' do
    let(:names) { subject.map(&:subscriber).sort }

    before do
      subject.add Subscription.new(subscriber: 'alice')
      subject.add Subscription.new(subscriber: 'bob')
    end

    it 'updates subscription list' do
      expect {
        subject.replace [
          Subscription.new(subscriber: 'charlie'),
          Subscription.new(subscriber: 'alice')
        ]
      }.to change {
        subject.map(&:subscriber).sort
      }.from(
        %w[alice bob]
      ).to(
        %w[alice charlie]
      )
    end
  end
end

