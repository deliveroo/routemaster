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
      expect(subject.subscribers.to_a).to eq([])
    end
  end

  
  describe '#fifo' do
    it 'returns a fifo' do
      expect(subject.fifo).to be_a_kind_of(Routemaster::Models::Fifo)
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
    let(:publish) { described_class.new(name: 'widgets', publisher: 'alice') }

    it 'returns an instance' do
      expect(result).to be_a_kind_of(described_class)
    end

    it 'lets the topic be published after' do
      result
      expect { publish }.not_to raise_error
    end

    context 'when the topic exists' do
      before { publish }
      it 'returns an instance' do
        expect(result).to be_a_kind_of(described_class)
      end
    end
  end
end
