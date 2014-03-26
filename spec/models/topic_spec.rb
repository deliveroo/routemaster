require 'spec_helper'
require 'spec/support/models.rb'
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
      }.to raise_error(Routemaster::Errors::TopicClaimed)
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


  describe '#push' do
    it 'succeeds with correct parameters' do
      expect {
        subject.push(event: 'create', url: 'https://example.com/widgets/123')
      }.not_to raise_error
    end

    it 'fails with incorrect event types' do
      expect {
        subject.push(event: 'whatever', url: 'https://example.com/widgets/123')
      }.to raise_error(ArgumentError)
    end

    it 'fails with a non-HTTPS URL' do
      expect {
        subject.push(event: 'create', url: 'http://example.com/widgets/123')
      }.to raise_error(ArgumentError)
    end

    it 'fails if the URL has a query string' do
      expect {
        subject.push(event: 'create', url: 'https://example.com/widgets/123?wut')
      }.to raise_error(ArgumentError)
    end
  end


  describe '#peek' do
    it 'returns nil if the topic has no events' do
      expect(subject.peek).to be_nil
    end

    it 'returns the oldest event for the topic' do
      subject.push(event: 'create', url: 'https://example.com/widgets/123')
      event = subject.peek
      expect(event.type).to eq('create')
      expect(event.url).to  eq('https://example.com/widgets/123')
    end

    it 'adds timestamps'  # should be an Event spec
  end


  describe '#pop' do
    it 'discards the oldest event for the topic'
  end


  describe '#events'
end
