require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/events'
require 'routemaster/services/watch'
require 'routemaster/models/subscription'
require 'core_ext/safe_thread'
require 'timeout'

describe Routemaster::Services::Watch do

  # describe '#start' do
  #   it 'starts the service' do
  #     subject.start
  #     expect(subject).to be_running
  #     subject.cancel
  #   end
  # end

  # describe '#join' do
  #   it 'waits for the service to complete' do
  #     subject.start
  #     SafeThread.new { subject.cancel }
  #     subject.join
  #     expect(subject).not_to be_running
  #   end
  # end

  # describe '#cancel' do
  #   it 'stops the service' do
  #     Timeout::timeout(5) do
  #       subject
  #       thread = SafeThread.new { subject.run }
  #       sleep(10.ms) until subject.running?
  #       subject.cancel
  #       expect(subject).not_to be_running
  #       expect(thread.status).to eq(false)
  #     end
  #   end
  # end

  describe '#run' do
    let(:subscription_a) { double 'subscription-a', subscriber: 'alice' }
    let(:subscription_b) { double 'subscription-b', subscriber: 'bob' }
    let(:receiver) { double 'receiver-service' }
    let(:subscriptions)  { [] }

    let(:perform) { subject.run(5) }

    before do
      allow(Routemaster::Models::Subscription).to receive(:each) do |&block|
        subscriptions.each { |s| block.call s }
      end

      allow(receiver).to receive(:run).and_return(0)
      allow(Routemaster::Services::Receive).to receive(:new).and_return(receiver)
    end

    it 'does nothing if no subscriptions' do
      expect(Routemaster::Services::Receive).not_to receive(:new)
      perform
    end

    context 'with multiple subscriptions' do
      before { subscriptions.replace [subscription_a, subscription_b] }

      it 'creates receiver services for each subscription' do
        expect(Routemaster::Services::Receive).to receive(:new)
        expect(receiver).to receive(:run).exactly(2).times
        subject.run(1)
      end
    end

    it 'creates receiver services for new subscriptions' do
      subscriptions << subscription_a
      expect(receiver).to receive(:run).once
      subject.run(1)
      subscriptions << subscription_b
      expect(receiver).to receive(:run).twice
      subject.run(1)
    end
  end
end
