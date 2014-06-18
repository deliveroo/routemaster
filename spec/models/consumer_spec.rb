require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/consumer'
require 'routemaster/models/subscription'
require 'core_ext/math'

describe Routemaster::Models::Consumer do
  class Receiver
    def initialize
      @messages = 0
    end

    def on_message(message)
      @messages += 1
    end

    def on_cancel
    end

    def wait_for_message(count: 1, timeout: 1.0)
      started_at    = Time.now
      until (Time.now > started_at + timeout) || (@messages >= count)
        sleep(10.ms)
      end
    end
  end

  let(:subscription) {
    Routemaster::Models::Subscription.new(subscriber: 'alice')
  }

  let(:receiver) { Receiver.new }

  let(:options) {{
    subscription: subscription,
    handler:      receiver
  }}

  subject { described_class.new(**options) }


  describe '#initialize' do
    it 'passes with valid args' do
      expect { subject }.not_to raise_error
    end

    it 'requires subscription:' do
      options.delete :subscription
      expect { subject }.to raise_error(ArgumentError)
    end

    it 'requires handler:' do
      options.delete :handler
      expect { subject }.to raise_error(ArgumentError)
    end
  end


  describe '#start' do
    it 'starts message delivery' do
      subscription.queue.publish('kill')
      expect(receiver).to receive(:on_message).with(instance_of(Routemaster::Models::Message))
      subject.start
      receiver.wait_for_message
    end

    it 'delivers multiple messages' do
      10.times { subscription.queue.publish('kill') }
      expect(receiver).to receive(:on_message).exactly(10).times
      subject.start
      receiver.wait_for_message(count: 10)
    end

    it 'can be called twice' do
      2.times { subject.start }
    end
  end

  describe '#stop' do
    it 'stops message delivery' do
      expect(receiver).not_to receive(:on_message)
      subject.start
      subject.stop
      receiver.wait_for_message
      subscription.queue.publish('kill')
    end

    it 'can be called twice' do
      subject.start
      2.times { subject.stop }
    end

    it 'can be called without starting' do
      subject.stop
    end
  end
end
