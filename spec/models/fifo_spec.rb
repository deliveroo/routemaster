require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/fifo'
require 'spec/support/events'

describe Routemaster::Models::Fifo do
  subject { described_class.new('topic-foos') }
  Widget = Class.new

  describe '.new' do
    it 'fails wihtout arguments' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end


  describe '#push' do
    it 'succeeds with correct parameters' do
      expect { subject.push(Widget.new) }.not_to raise_error
    end
  end


  describe '#peek' do
    it 'returns nil if the topic has no events' do
      expect(subject.peek).to be_nil
    end

    it 'returns the oldest event for the topic' do
      subject.push(:a)
      subject.push(:b)
      expect(subject.peek).to eq(:a)
    end
  end


  describe '#pop' do
    it 'returns nothing when the topic is empty' do
      expect(subject.pop).to be_nil
    end


    it 'discards the oldest event for the topic' do
      subject.push(:a)
      subject.push(:b)
      expect(subject.pop).to eq(:a)
      expect(subject.pop).to eq(:b)
    end
  end

  describe '#block_pop' do
    it 'blocks for 1 second if empty' do
      timestamp = Routemaster.now
      subject.block_pop
      expect(Routemaster.now).to be > (timestamp + 1_000)
    end

    context 'when not empty' do
      before { subject.push :a }

      it 'returns an item' do
        expect(subject.block_pop).not_to be_nil
      end

      it 'removes the item'
    end
  end
end

