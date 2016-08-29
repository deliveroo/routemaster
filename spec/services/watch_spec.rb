require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/events'
require 'spec/support/dummy'
require 'spec/support/env'
require 'routemaster/application'
require 'routemaster/services/watch'
require 'routemaster/models/subscriber'
require 'timeout'

describe Routemaster::Services::Watch do

  describe '#run' do
    let(:subscriber_a) { double 'subscriber-a', subscriber: 'alice' }
    let(:subscriber_b) { double 'subscriber-b', subscriber: 'bob' }
    let(:receiver) { double 'receiver-service', time_to_next_run: 0, batch_size: 0 }
    let(:subscribers)  { [] }

    let(:perform) { subject.run(2) }
    let(:app) { Routemaster::Application }

    before do
      ENV['EXCEPTION_SERVICE'] = 'dummy'
    end

    shared_examples 'logging' do
      it 'logs exception' do
        expect(receiver).to receive(:run).and_raise(StandardError)
        expect(Routemaster::Services::ExceptionLoggers::Dummy.instance).to receive(:process)
        subscribers << subscriber_a
        expect{ subject.run(1) }.to raise_error(StandardError)
      end
    end

    before do
      allow(Routemaster::Models::Subscriber).to receive(:each) do |&block|
        subscribers.each { |s| block.call s }
      end

      allow(receiver).to receive(:run).and_return(0)
      allow(Routemaster::Services::Receive).to receive(:new).and_return(receiver)
    end

    it 'does nothing if no subscribers' do
      expect(Routemaster::Services::Receive).not_to receive(:new)
      perform
    end

    context 'with multiple subscribers' do
      before { subscribers.replace [subscriber_a, subscriber_b] }

      it 'creates receiver services for each subscriber' do
        expect(Routemaster::Services::Receive).to receive(:new)
        expect(receiver).to receive(:run).exactly(2).times
        subject.run(1)
      end
    end

    it 'creates receiver services for new subscribers' do
      subscribers << subscriber_a
      expect(receiver).to receive(:run).once
      subject.run(1)
      subscribers << subscriber_b
      expect(receiver).to receive(:run).twice
      subject.run(1)
    end

    include_examples 'logging'
  end
end
