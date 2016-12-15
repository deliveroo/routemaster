require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/events'
require 'spec/support/dummy'
require 'spec/support/env'
require 'routemaster/services/worker'
require 'routemaster/services/codec'
require 'routemaster/services/deliver'

module Routemaster
  describe Services::Worker do
    subject { described_class.new(delivery: delivery) }

    let(:subscriber) {
      Routemaster::Models::Subscriber.new(name: 'alice').tap do |s|
        s.timeout = 0
      end
    }
    let(:messages) { [make_event, make_event] }
    let(:delivery) { double 'delivery', call:nil }
    let(:perform) { subject.call }

    before do
      ENV['EXCEPTION_SERVICE'] = 'dummy'
      
      messages.each do |msg|
        Models::Batch.ingest(
          subscriber: subscriber,
          timestamp:  msg.timestamp,
          data:       Services::Codec.new.dump(msg))
      end
      Models::Batch.auto_promote
    end

    describe '#call' do
      context 'at rest' do
        let(:messages) { [] }
        it { expect { perform }.not_to raise_error }
        it { expect(perform).to eq(false) }
      end

      context 'when there is a batch to acquire' do
        it { expect { perform }.not_to raise_error }
        it { expect(perform).to eq(true) }
        it 'attempts delivery' do
          expect(delivery).to receive(:call) do |sub,ev|
            expect(sub).to eq(subscriber)
            expect(ev).to eq(messages)
          end
          perform
        end
      end

      #   it 'logs exception' do
      #     expect(receiver).to receive(:run).and_raise(StandardError)
      #     expect(Routemaster::Services::ExceptionLoggers::Dummy.instance).to receive(:process)
      #     subscribers << subscriber_a
      #     expect{ subject.run(1) }.to raise_error(StandardError)
      #   end
      # end
    end

    describe '#last_at' do
      let(:result) { subject.last_at }

      it { expect(result).to be_nil }

      context 'once the worker has run' do
        before { perform }

        it { expect(perform).to eq(true) }
        it { expect(result).to be_between(Routemaster.now - 1000, Routemaster.now) }
        # it { expect(result).to be_less_than(Time.now) }
      end
      
    end
  end
end
