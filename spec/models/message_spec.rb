require 'spec_helper'
require 'routemaster/models/message'

describe Routemaster::Models::Message do
  let(:properties) { double 'properties' }
  let(:uid) { nil }
  let(:payload) {
    Routemaster::Models::Event.new(
      topic: 'widgets',
      type:  'create',
      url:   'https://example.com/widgets/123'
    ).dump
  }

  subject { described_class.new(payload, uid) }

  describe '#kill?' do
    it 'is true when payload is "kill"' do
      payload.replace 'kill'
      expect(subject).to be_kill
    end

    it 'is false otherwise' do
      expect(subject).not_to be_kill
    end
  end

  describe '#event?' do
    it 'is true for valid event data' do
      expect(subject).to be_event
    end

    it 'is false for kill messages' do
      payload.replace 'kill'
      expect(subject).not_to be_event
    end

    it 'is false for gibberish' do
      payload.replace 'whatever'
      expect(subject).not_to be_event
    end
  end

  describe '#event' do
    it 'is nil for non-events' do
      payload.replace 'kill'
      expect(subject.event).to be_nil
    end

    it 'returns an Event otherwise' do
      expect(subject.event).to be_a_kind_of(Routemaster::Models::Event)
    end
  end

  describe '#uid' do
    it 'is generated' do
      expect(subject.uid).to match /^\h{8}-\h{4}-\h{4}-\h{4}-\h{12}$/
    end

    context 'when specified' do
      let(:uid) { 'abcd-1234' }

      it 'is honoured' do
        expect(subject.uid).to eq('abcd-1234')
      end
    end
  end
end
