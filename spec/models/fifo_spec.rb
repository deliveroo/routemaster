require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/fifo'

describe Routemaster::Models::Fifo do
  subject { described_class.new('topic-widgets') }

  describe '.new' do
    it 'fails wihtout arguments' do
      expect { described_class.new }.to raise_error(ArgumentError)
    end
  end


  let(:event) {
    Routemaster::Models::Event.new(
      topic: 'widgets',
      type:  'create', 
      url:   'https://example.com/widgets/123')
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
    let(:event1) { Routemaster::Models::Event.new(topic: 'widgets', type: 'create', url: 'https://a.com/1') }
    let(:event2) { Routemaster::Models::Event.new(topic: 'widgets', type: 'create', url: 'https://a.com/2') }

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
end

