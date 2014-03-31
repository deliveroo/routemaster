require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/topic'

describe Routemaster::Models::Topic do
  subject { described_class.new(name: 'widgets', publisher: 'bob') }

  describe '.new' do
    it 'fails wihtout arguments' do
      expect {
        described_class.new
      }.to raise_error(ArgumentError)
    end

    it 'succeeds in a blank slate' do
      expect(
        described_class.new(name: 'widgets', publisher: 'bob')
      ).to be_a_kind_of(described_class)
    end

    it 'fails if the topic is claimed by another publisher' do
      described_class.new(name: 'widgets', publisher: 'bob')
      expect {
        described_class.new(name: 'widgets', publisher: 'alice')
      }.to raise_error(described_class::TopicClaimedError)
    end
  end


  describe '#publisher' do
    it 'returns the channel publisher' do
      expect(subject.publisher).to eq('bob')
    end

  end


  describe '#subscribers' do
    it 'returns the list of channel subscribers' do
      expect(subject.subscribers).to eq([])
    end
  end


  let(:event) {
    Routemaster::Models::Event.new(
      type: 'create', 
      url: 'https://example.com/widgets/123')
  }

  describe '#push' do
    it 'succeeds with correct parameters' do
      expect { subject.push(event) }.not_to raise_error
    end
  end


  describe '#peek' do
    it 'returns nil if the topic has no events' do
      expect(subject.peek).to be_nil
    end

    it 'returns the oldest event for the topic' do
      subject.push(event)
      event = subject.peek
      expect(event.type).to eq('create')
      expect(event.url).to  eq('https://example.com/widgets/123')
    end
  end


  describe '#pop' do
    let(:event1) { Routemaster::Models::Event.new(type: 'create', url: 'https://a.com/1') }
    let(:event2) { Routemaster::Models::Event.new(type: 'create', url: 'https://a.com/2') }

    it 'returns nothing when the topic is empty' do
      expect(subject.pop).to be_nil
    end


    it 'discards the oldest event for the topic' do
      subject.push(event1)
      subject.push(event2)
      expect(subject.pop).to eq(event1)
      expect(subject.pop).to eq(event2)
    end
  end


  describe '.all' do
    it 'is empty in a blank state' do
      expect(described_class.all).to be_empty
    end

    it 'lists all topics' do
      topic1 = described_class.new(name: 'widgets', publisher: 'john')
      topic2 = described_class.new(name: 'koalas',  publisher: 'john')

      expect(described_class.all).to include(topic1)
      expect(described_class.all).to include(topic2)
    end
  end
end
