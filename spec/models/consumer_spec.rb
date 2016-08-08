require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/consumer'
require 'routemaster/models/subscription'
require 'core_ext/math'

describe Routemaster::Models::Consumer do
  let(:kill_message) {
    Routemaster::Models::Message.new('kill')
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
      expect(message).to be_a_kind_of(Routemaster::Models::Message)
      expect(message).to be_kill
    end

    it 'delivers multiple messages' do
      10.times do
        described_class.push [subscription], kill_message
      end
      10.times do
        expect(subject.pop).to be_kill
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
      expect(subject.pop).to be_kill
    end

    it 'requeues just once' do
      subject.nack(message)
      subject.nack(message)
      expect(subject.pop).to be_kill
      expect(subject.pop).to be_nil
    end
  end
end
