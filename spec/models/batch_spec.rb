require 'spec_helper'
require 'spec/support/events'
require 'routemaster/models/batch'
require 'routemaster/models/message'

describe Routemaster::Models::Batch do
  let(:queue) { double 'queue' }
  let(:now) { Routemaster.now }
  let(:events) { [make_event, make_event] }
  let(:messages) {[
    Routemaster::Models::Message::Kill.new(timestamp: now - 100),
    Routemaster::Models::Message::Kill.new(timestamp: now - 300),
    *events,
    Routemaster::Models::Message::Kill.new(timestamp: now - 200),
  ]}

  subject { described_class.new(queue) }

  before do
    messages.each { |m| subject.push(m) }
  end

  describe '#length' do
    it { expect(subject.length).to eq(5) }
  end

  describe 'acknowledgments' do
    let(:perform) { subject.public_send(method) }
    let(:results) { [] }

    shared_examples 'ack-nack' do
      before do
        allow(queue).to receive(method) do |msg|
          results << msg
        end
      end

      it 'empties the batch' do
        expect { perform }.to change { subject.length }.to(0)
      end

      it 'passes the message to the queue' do
        perform
        expect(results).to eq(messages)
      end
    end

    describe '#nack' do
      let(:method) { :nack }
      include_examples 'ack-nack'
    end

    describe '#ack' do
      let(:method) { :ack }
      include_examples 'ack-nack'
    end
  end

  describe '#events' do
    it 'lists events' do
      expect(subject.events).to eq(events)
    end
  end

  describe '#age' do
    it 'picks the oldest message' do
      expect(subject.age).to be_within(50).of(300)
    end
  end
end
