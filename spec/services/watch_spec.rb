require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/events'
require 'routemaster/services/watch'
require 'routemaster/models/subscription'
require 'core_ext/safe_thread'
require 'timeout'

describe Routemaster::Services::Watch do

  describe '#start' do
    it 'starts the service' do
      subject.start
      expect(subject).to be_running
      subject.cancel
    end
  end

  describe '#join' do
    it 'waits for the service to complete' do
      subject.start
      SafeThread.new { subject.cancel }
      subject.join
      expect(subject).not_to be_running
    end
  end

  describe '#cancel' do
    it 'stops the service' do
      Timeout::timeout(5) do
        subject
        thread = SafeThread.new { subject.run }
        sleep 10e-3 until subject.running?
        subject.cancel
        expect(subject).not_to be_running
        expect(thread.status).to be_false
      end
    end
  end

  describe '#run' do
    let(:subscription_a) { double 'subscription-a', subscriber: 'alice' }
    let(:subscription_b) { double 'subscription-b', subscriber: 'bob' }
    let(:receiver) { double 'receiver-service' }
    let(:subscriptions)  { [] }

    let(:perform) do
      Timeout::timeout(60) do
        subject.start
        sleep 1
        subject.cancel
      end
    end

    before do
      allow(Routemaster::Models::Subscription).to receive(:each) do |&block|
        subscriptions.each { |s| block.call s }
      end

      allow(receiver).to receive(:start).and_return(receiver)
      allow(receiver).to receive(:cancel).and_return(receiver)
      allow(Routemaster::Services::Receive).to receive(:new).and_return(receiver)
    end

    it 'does nothing if no subscriptions' do
      expect(Routemaster::Services::Receive).not_to receive(:new)
      perform
    end

    context 'with multiple subscriptions' do
      before { subscriptions << subscription_a << subscription_b }

      it 'creates receiver services for each subscription' do
        expect(Routemaster::Services::Receive).to receive(:new)
        expect(receiver).to receive(:start).exactly(2).times
        perform
      end

      it 'stops receiver services when ending' do
        expect(receiver).to receive(:stop).exactly(2).times
        perform
      end
    end

    it 'creates receiver services for new subscriptions' do
      subscriptions << subscription_a
      subject.start
      sleep 250e-3
      subscriptions << subscription_b
      expect(receiver).to receive(:start).once
      sleep 250e-3
      subject.cancel
    end
  end
end
