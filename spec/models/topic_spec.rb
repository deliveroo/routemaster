require 'spec_helper'
require 'routemaster/models/topic'

describe Routemaster::Models::Topic do
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
      }.to raise_error(Routemaster::Errors::TopicClaimed)
    end
  end

  describe '#publisher' do
    it 'returns the channel publisher'
  end

  describe '#subscribers' do
    it 'returns the list of channel subscribers'
  end

  describe '#push' do
    it 'succeeds with correct parameters'
    it 'fails with incorrect event types'
    it 'fails with a bad URL'
  end

  describe '#peek' do
    it 'returns the oldest event for the topic'
  end

  describe '#pop' do
    it 'discards the oldest event for the topic'
  end

  describe '#events'
end
