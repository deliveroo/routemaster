require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/queue'
require 'routemaster/models/subscription'
require 'core_ext/math'

describe Routemaster::Models::Queue do
  let(:kill_message) {
    Routemaster::Models::Message::Kill.new
  }
  let(:subscription) {
    Routemaster::Models::Subscription.new(subscriber: 'alice')
  }

  let(:options) {[ subscription ]}

  subject { described_class.new(*options) }


  describe '#initialize' do
    it 'passes with valid args' do
      expect { subject }.not_to raise_error
    end

    it 'requires subscription:' do
      options.clear
      expect { subject }.to raise_error(ArgumentError)
    end
  end


  describe '#pop' do
    it 'returns a queued message' do
      described_class.push [subscription], kill_message
      message = subject.pop
      expect(message).to be_a_kind_of(Routemaster::Models::Message::Kill)
    end

    it 'delivers multiple messages in order' do
      10.times do |n|
        described_class.push [subscription], Routemaster::Models::Message::Ping.new(data: "msg#{n}")
      end
      10.times do |n|
        expect(subject.pop.data).to eq("msg#{n}")
      end
    end

    it 'returns nil after the last message' do
      described_class.push [subscription], kill_message
      subject.pop
      expect(subject.pop).to be_nil
    end

    it 'returns nil when there are no queued messages' do
      subject.pop
      expect(subject.pop).to be_nil
    end
  end

  describe '#ack' do
    let(:message) { subject.pop }

    before do
      described_class.push [subscription], kill_message
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
      described_class.push [subscription], kill_message
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
      5.times { |n| described_class.push [subscription], Routemaster::Models::Message::Ping.new(data: "msg#{n}") }
      2.times { subject.pop }
      expect(subject.length).to eq(5)
    end
  end

  describe '#staleness' do

    let(:subscription) {
      Routemaster::Models::Subscription.new(subscriber: 'alice')
    }
    let(:options) {[ subscription ]}
    let(:queue) { Routemaster::Models::Queue.new(*options) }
    let(:event) {
      Routemaster::Models::Event.new(
        topic: 'widgets',
        type:  'create',
        url:   'https://example.com/widgets/123'
      )
    }

    before do
      Routemaster::Models::Queue.push [subscription], event
    end

    it 'should return the age of the oldest message' do
      sleep(250e-3)
      expect(queue.staleness).to be_within(50).of(250)
    end

    it 'does not dequeue the oldest message' do
      queue.staleness
      expect(queue.pop).to be_a_kind_of(Routemaster::Models::Event)
    end
  end
end
