require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/services/receive'
require 'routemaster/models/subscription'

describe Routemaster::Services::Receive do
  
  let(:subscription) {
    Routemaster::Models::Subscription.new(subscriber: 'alice')
  }

  class FakeDeliver
    attr_reader :events

    def initialize(_, events)
      @events = events
    end

    def run
      true
    end
  end

  let(:max_events) { [nil] }

  let(:options) {[
   subscription, max_events.first
  ]}

  subject { described_class.new(*options) }

  def wait_for(timeout: 1, &block)
    started_at = Time.now
    until Time.now > started_at + timeout || block.call
      sleep 10e-3
    end
  end

  describe '#initialize' do
    it 'passes with valid args' do
      expect { subject }.not_to raise_error
    end
  end

  describe '#on_message' do
    let(:perform) { messages.each { |m| subject.on_message(m) } }
    let(:delivery) { double 'delivery' }

    before do
      allow(Routemaster::Services::Deliver).to receive(:new) { |sub, events|
        @delivered_events = events
        delivery
      }
    end

    context 'when receiving a kill message' do
      let(:messages) {[
        Routemaster::Models::Message.new(nil, nil, 'kill')
      ]}

      it 'acks the message' do
        expect(messages.first).to receive(:ack)
        perform
      end

      it 'stops the service' do
        subject.start
        perform
        wait_for { ! subject.running? }
        expect(subject).not_to be_running
      end
    end

    context 'when receiving an unknown event' do
      let(:messages) {[
        Routemaster::Models::Message.new(nil, nil, 'do you even compute')
      ]}

      it 'acks the message' do
        expect(messages.first).to receive(:ack)
        perform
      end
    end

    context 'when receiving an event' do
      def make_message(id)
        event = Routemaster::Models::Event.new(
          topic: 'widgets', type: 'create',
          url: "https://example.com/widgets/#{id}",
        )
        Routemaster::Models::Message.new(nil, nil, event.dump)
      end

      let(:messages) {[
        make_message(0), make_message(1), make_message(2)
      ]}

      let(:delivery_result) { [] }

      before do
        allow(delivery).to receive(:run) do
          case value = delivery_result.pop
          when :fail
            raise Routemaster::Services::Deliver::CantDeliver
          else
            value
          end
        end
      end

      it 'acks the message on successful delivery' do
        delivery_result << true << true << true
        messages.each do |m|
          expect(m).to receive(:ack)
        end
        perform
      end

      it 'does not (n)ack on non-delivery' do
        delivery_result << false << false << false
        expect(messages.first).not_to receive(:ack)
        expect(messages.first).not_to receive(:nack)
        perform
      end

      it 'delivers messages in batches' do
        delivery_result << false << false << false
        perform
        expect(@delivered_events.length).to eq(3)
        expect(@delivered_events).to eq(messages.map(&:event))
      end

      context 'when delivery fails' do
        it 'keeps events for next delivery' do
          delivery_result << :fail << :fail << :fail
          perform
          expect(@delivered_events.length).to eq(3)
        end
      end

      context 'when receiving the maximum events' do
        it 'stops the service' do
          max_events.replace([3])
          subject.start
          expect(subject).to be_running
          perform
          expect(subject).not_to be_running
        end
      end
    end
  end

  describe '#on_cancel' do
    it 'nacks previsouly received events'
  end
  
end
