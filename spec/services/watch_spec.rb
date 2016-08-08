require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/events'
require 'spec/support/dummy'
require 'routemaster/application'
require 'routemaster/services/watch'
require 'routemaster/models/subscription'
require 'timeout'

describe Routemaster::Services::Watch do

  describe '#run' do
    let(:subscription_a) { double 'subscription-a', subscriber: 'alice' }
    let(:subscription_b) { double 'subscription-b', subscriber: 'bob' }
    let(:receiver) { double 'receiver-service', time_to_next_run: 0, batch_size: 0 }
    let(:subscriptions)  { [] }

    let(:perform) { subject.run(2) }
    let(:app) { Routemaster::Application }

    around do |example|
      old = ENV['EXCEPTION_SERVICE']
      ENV['EXCEPTION_SERVICE'] = 'dummy'
      example.run
      ENV['EXCEPTION_SERVICE'] = old
    end

    shared_examples 'logging' do
      it 'logs exception' do
        expect(receiver).to receive(:run).and_raise(StandardError)
        expect(Routemaster::Services::ExceptionLoggers::Dummy.instance).to receive(:process)
        subscriptions << subscription_a
        expect{ subject.run(1) }.to raise_error(StandardError)
      end
    end

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

    include_examples 'logging'
  end
end
