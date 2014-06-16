require 'spec_helper'
require 'routemaster/models/message'

describe Routemaster::Models::Message do
  let(:bunny) { double 'bunny', ack: true, nack: true }
  let(:delivery_info) { double 'delivery_info', delivery_tag: 'foo' }
  let(:properties) { double 'properties' }
  let(:payload) {
    Routemaster::Models::Event.new(
      topic: 'widgets',
      type:  'create',
      url:   'https://example.com/widgets/123'
    ).dump
  }
  
  before { allow(subject).to receive(:bunny).and_return(bunny) }

  subject { described_class.new(delivery_info, properties, payload) }

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

  describe 'event' do 
    it 'is nil for non-events' do
      payload.replace 'kill'
      expect(subject.event).to be_nil
    end

    it 'returns an Event otherwise' do
      expect(subject.event).to be_a_kind_of(Routemaster::Models::Event)
    end
  end

  shared_examples 'ack and nack' do |method, other|
    it "#{method}s the message" do
      expect(bunny).to receive(method)
      subject.public_send(method)
    end

    it 'can be called twice' do
      subject.public_send(method)
      expect { subject.public_send(method) }.not_to raise_error
    end

    it 'acks only once' do
      expect(bunny).to receive(method).once
      2.times { subject.public_send(method) }
    end

    it 'passes for non-events' do
      payload.replace 'kill'
      expect(bunny).to receive(method)
      subject.public_send(method)
    end

    it 'fails if nack has been called' do
      subject.public_send(other)
      expect { subject.public_send(method) }.to raise_error
    end
  end

  describe '#ack' do
    it_should_behave_like 'ack and nack', :ack, :nack
  end

  describe '#nack' do
    it_should_behave_like 'ack and nack', :nack, :ack
  end
end
