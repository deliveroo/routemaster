require 'spec_helper'
require 'routemaster/services/receive'
require 'routemaster/models/subscription'
require 'core_ext/math'

describe Routemaster::Services::Receive do

  let(:subscription) {
    Routemaster::Models::Subscription.new(subscriber: 'alice')
  }

  let(:max_events) { [10] }
  let(:options) {[ subscription, max_events.first ]}

  subject { described_class.new(*options) }

  class FakeDeliver
    attr_accessor :events, :results

    def initialize
      @results = []
    end

    def run
      result = results.pop
      raise Routemaster::Services::Deliver::CantDeliver if result == :fail
      result
    end
  end

  def make_message(id)
    Routemaster::Models::Event.new(
      topic: 'widgets', type: 'create',
      url: "https://example.com/widgets/#{id}",
    )
  end


  describe '#initialize' do
    it 'passes with valid args' do
      expect { subject }.not_to raise_error
    end
  end

  describe '#run' do
    let(:delivery) { FakeDeliver.new }
    let(:messages) { [] }
    let(:acked_messages) { [] }
    let(:nacked_messages) { [] }

    before do
      messages_to_deliver = messages.dup
      allow_any_instance_of(Routemaster::Models::Queue).to receive(:pop) do
        messages_to_deliver.pop
      end

      allow_any_instance_of(Routemaster::Models::Queue).to receive(:ack) do |_,msg|
        acked_messages << msg
      end

      allow_any_instance_of(Routemaster::Models::Queue).to receive(:nack) do |_,msg|
        nacked_messages << msg
      end

      allow(Routemaster::Services::Deliver).to receive(:new) { |sub, events|
        delivery.events = events
        delivery
      }
    end

    context 'when receiving a kill message' do
      let(:messages) {[
        Routemaster::Models::Message::Kill.new
      ]}

      it 'acks the message' do
        expect { subject.run }.to raise_error(Routemaster::Services::Receive::KillError)
        expect(acked_messages).to eq(messages)
      end

      it 'raises KillError' do
        expect { subject.run }.to raise_error(Routemaster::Services::Receive::KillError)
      end
    end

    context 'when receiving an unknown event' do
      let(:messages) {[
        Routemaster::Models::Message::Ping.new
      ]}

      it 'acks the message' do
        subject.run
        expect(acked_messages).to eq(messages)
      end

      it 'schedules a delivery' do
        expect(delivery).to receive(:run)
        subject.run
      end
    end

    context 'when events are queued' do
      let(:messages) {[
        make_message(0), make_message(1), make_message(2)
      ]}

      it 'returns the number of events' do
        expect(subject.run).to eq(3)
      end

      it 'acks the message on successful delivery' do
        delivery.results = [true, true, true]
        subject.run
        expect(acked_messages).to eq(messages.reverse)
      end

      it 'does not (n)ack on non-delivery' do
        delivery.results = [false, false, false]
        subject.run
        expect(acked_messages).to be_empty
        expect(nacked_messages).to be_empty
      end

      it 'delivers messages in batches' do
        delivery.results = [false, false, false]
        subject.run
        expect(delivery.events.length).to eq(3)
      end

      context 'when delivery fails' do
        before do
          delivery.results = [:fail, :fail, :fail]
        end

        it 'drops events before next delivery' do
          subject.run
          expect(delivery.events.length).to eq(0)
        end

        it 'nacks events' do
          subject.run
          expect(nacked_messages).to include(messages.first)
        end
      end

      context 'when receiving the maximum events' do
        it 'only processes the max' do
          max_events.replace([2])
          delivery.results = [true, true, true]
          # expect(messages).to receive(:pop).twice.and_call_original
          subject.run
          expect(acked_messages).to eq(messages.last(2).reverse)
          expect(nacked_messages).to be_empty
        end
      end
    end
  end
end
