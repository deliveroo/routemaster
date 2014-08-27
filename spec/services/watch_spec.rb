require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/events'
require 'routemaster/services/watch'
require 'routemaster/models/subscription'
require 'core_ext/safe_thread'
require 'timeout'

describe Routemaster::Services::Watch do

  describe '#run' do
    let(:subscription_a) { double 'subscription-a', subscriber: 'alice' }
    let(:subscription_b) { double 'subscription-b', subscriber: 'bob' }
    let(:receiver) { double 'receiver-service', time_to_next_run: 0, batch_size: 0 }
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

    it 'logs to New Relic when rescuing StandardError and re-raises' do
      subscriptions << subscription_a
      expect(receiver).to receive(:run).and_raise(StandardError)
      expect(NewRelic::Agent).to receive(:notice_error)
        .with(StandardError)

      expect{ subject.run(1) }.to raise_error(StandardError)
    end
  end
end
