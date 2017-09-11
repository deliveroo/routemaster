require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/events'
require 'spec/support/dummy'
require 'spec/support/env'
require 'routemaster/jobs/batch'
require 'routemaster/services/codec'
require 'routemaster/services/deliver'

module Routemaster
  describe Jobs::Batch do
    subject { described_class.new(delivery: delivery) }

    let(:subscriber) {
      Routemaster::Models::Subscriber.new(name: 'alice').tap { |s|
        s.timeout = 0
      }.save
    }
    let(:messages) { [make_event, make_event] }
    let(:delivery) { double 'delivery', call: nil }
    let(:perform) { 
      begin
        subject.call(batch.uid)
      rescue => e
        @error = e
      end
    }

    let(:batch) {
      messages.map { |msg|
        Models::Batch.ingest(
          subscriber: subscriber,
          timestamp:  msg.timestamp,
          data:       Services::Codec.new.dump(msg))
      }.last
    }

    before do
      ENV['EXCEPTION_SERVICE'] = 'dummy'
    end

    describe '#call' do
      it { subject.call(batch.uid) }
      it { expect { perform }.not_to change { @error } }

      it 'attempts delivery' do
        expect(delivery).to receive(:call) do |b,ev|
          expect(b.uid).to eq(batch.uid)
          expect(ev).to eq(messages)
        end
        perform
      end

      context 'when the batch  has been deleted' do
        before { batch.promote.delete }

        it 'does not fail' do
          expect { perform }.not_to change { @error }
        end

        it 'does not attempt delivery' do
          expect(delivery).not_to receive(:call)
          perform
        end
      end

      context 'when delivery fails' do
        let(:delay_ms) { 42.0 }
        before { allow(delivery).to receive(:call).and_raise(Routemaster::Exceptions::DeliveryFailure.new("Failed!", delay_ms)) }

        it 'raise a Retry error' do
          perform
          expect(@error).to be_a_kind_of(Models::Queue::Retry)
        end
        
        it 'sets a retry delay' do
          perform
          expect(@error.delay).to eq delay_ms
        end

        it 'logs the error' do
          expect(Services::Logger.instance).to receive(:warn) do |&block|
            expect(block.call).to match /DeliveryFailure|CantDeliver|EarlyThrottle/
          end
          perform  
        end
      end

      context 'when subscriber has been removed' do
        before { subscriber.destroy }

        it 'does not fail' do
          expect { perform }.not_to change { @error }
        end

        it 'deletes the batch' do
          perform
          expect(batch.reload).not_to exist
        end
      end
    end
  end
end
