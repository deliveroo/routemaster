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


  describe 'marshalling' do
    let(:result) { Marshal.load(Marshal.dump(subject)) }

    it 'can be marshalled/unmarshalled' do
      expect(result.name).to eq('widgets')
      expect(result.publisher).to eq('bob')
    end
  end


  describe '#publisher' do
    it 'returns the channel publisher' do
      expect(subject.publisher).to eq('bob')
    end

  end


  describe '#subscribers' do
    it 'returns the list of channel subscribers' do
      expect(subject.subscribers.to_a).to eq([])
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

  describe '.find' do
    let(:result) { described_class.find('widgets') }
    it 'returns existing topics' do
      subject
      expect(result).to eq(subject)
    end

    it 'returns nil for unknown topics' do
      expect(result).to be_nil
    end
  end

  describe 'push' do

    let(:options) do
      {
        topic: 'widgets',
        type: 'create',
        url: 'https://example.com/widgets/123'
      }
    end
    let(:event) { Routemaster::Models::Event.new(**options) }

    it 'increments the topic counter' do
      expect(subject.get_count).to eql 0
      subject.push(event)
      expect(subject.get_count).to eql 1
    end
  end
end
