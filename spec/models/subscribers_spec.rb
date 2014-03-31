require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/subscribers'
require 'routemaster/models/queue'

describe Routemaster::Models::Subscribers do
  Queue = Routemaster::Models::Queue

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
    xit 'yields queues'
  end

  describe '#add' do
    it 'adds the subscriber' do
      subject.add Queue.new(subscriber: 'bob')
      expect(subject.first.subscriber).to eq('bob')
    end

    it 'behaves like a set' do
      subject.add Queue.new(subscriber: 'alice')
      subject.add Queue.new(subscriber: 'bob')
      subject.add Queue.new(subscriber: 'alice')
      expect(subject.count).to eq(2)
    end
  end
end

