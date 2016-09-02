require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/queue'
require 'routemaster/models/subscriber'
require 'core_ext/math'

describe Routemaster::Models::Queue do
  let(:kill_message) {
    Routemaster::Models::Message::Kill.new
  }
  let(:subscriber) {
    Routemaster::Models::Subscriber.new(name: 'alice')
  }

  let(:options) {[ subscriber ]}

  subject { described_class.new(*options) }


  describe '#initialize' do
    it 'passes with valid args' do
      expect { subject }.not_to raise_error
    end

    it 'requires subscriber:' do
      options.clear
      expect { subject }.to raise_error(ArgumentError)
    end
  end


  describe '#pop' do
    it 'returns a queued message' do
      described_class.push [subscriber], kill_message
      message = subject.pop
      expect(message).to be_a_kind_of(Routemaster::Models::Message::Kill)
    end

    it 'delivers multiple messages in order' do
      10.times do |n|
        described_class.push [subscriber], Routemaster::Models::Message::Ping.new(data: "msg#{n}")
      end
      10.times do |n|
        expect(subject.pop.data).to eq("msg#{n}")
      end
    end

    it 'returns nil after the last message' do
      described_class.push [subscriber], kill_message
      subject.pop
      expect(subject.pop).to be_nil
    end

    it 'returns nil when there are no queued messages' do
      subject.pop
      expect(subject.pop).to be_nil
    end
  end

  describe '#peek' do
    context 'when empty' do
      it { expect(subject.peek).to be_nil }
    end

    context 'with queued messages' do
      let(:messages) {[
        Routemaster::Models::Message::Ping.new(data: "msg1"),
        Routemaster::Models::Message::Ping.new(data: "msg2"),
      ]}

      before do
        messages.each do |msg|
          described_class.push [subscriber], msg
        end
      end

      it 'returns the oldest message' do
        expect(subject.peek).to eq(messages.first)
      end

      it 'does not dequeue'
    end
  end

  describe '#drop' do
    context 'when empty' do
      it { expect(subject.drop(10)).to eq(0) }
    end

    context 'with queued messages' do
      let(:messages) {[
        Routemaster::Models::Message::Ping.new(data: "msg1"),
        Routemaster::Models::Message::Ping.new(data: "msg2"),
        Routemaster::Models::Message::Ping.new(data: "msg3"),
      ]}

      before do
        messages.each do |msg|
          described_class.push [subscriber], msg
        end
      end

      it 'removes messages' do
        expect { subject.drop(2) }.to change { subject.length }.from(3).to(1)
      end

      it 'returns the right count' do
        expect(subject.drop(4)).to eql(3)
      end
    end
  end

  describe '#ack' do
    let(:message) { subject.pop }

    before do
      described_class.push [subscriber], kill_message
    end

    it 'does not requeue' do
      subject.ack(message)
      expect(subject.pop).to be_nil
    end

    it 'is idempotent' do
      subject.ack(message)
      subject.ack(message)
      expect(subject.pop).to be_nil
    end
  end

  describe '#nack' do
    let(:message) { subject.pop }

    before do
      described_class.push [subscriber], kill_message
    end

    it 'requeues the message' do
      subject.nack(message)
      expect(subject.pop).to eq(message)
    end

    it 'requeues just once' do
      subject.nack(message)
      subject.nack(message)
      expect(subject.pop).to eq(message)
      expect(subject.pop).to be_nil
    end
  end

  describe '#length' do
    it 'is zero at rest' do
      expect(subject.length).to eq(0)
    end

    it 'counts new and un-acked messages' do
      5.times { |n| described_class.push [subscriber], Routemaster::Models::Message::Ping.new(data: "msg#{n}") }
      2.times { subject.pop }
      expect(subject.length).to eq(5)
    end
  end

  describe '#staleness' do

    let(:subscriber) {
      Routemaster::Models::Subscriber.new(name: 'alice')
    }
    let(:options) {[ subscriber ]}
    let(:queue) { Routemaster::Models::Queue.new(*options) }
    let(:event) {
      Routemaster::Models::Event.new(
        topic: 'widgets',
        type:  'create',
        url:   'https://example.com/widgets/123'
      )
    }

    before do
      Routemaster::Models::Queue.push [subscriber], event
    end

    it 'should return the age of the oldest message' do
      sleep(150e-3)
      expect(queue.staleness).to be_within(50).of(150)
    end

    it 'does not dequeue the oldest message' do
      queue.staleness
      expect(queue.pop).to be_a_kind_of(Routemaster::Models::Event)
    end
  end
end
