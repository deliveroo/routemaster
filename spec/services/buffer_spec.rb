require 'spec_helper'
require 'routemaster/services/buffer'
require 'routemaster/models/subscription'
require 'spec/support/persistence'
require 'spec/support/events'

describe Routemaster::Services::Buffer do
  let(:subscription) { Routemaster::Models::Subscription.new(subscriber: 'alice') } 
  let(:buffer) { subscription.buffer }
  
  subject { described_class.new(subscription) }

  before { subscription.max_events = 3 }

  describe '#run' do
    let(:perform) { subject.run }

    shared_examples 'doing nothing' do
      it 'passes' do
        expect { perform }.not_to raise_error
      end

      it 'does not change the buffer' do
        buffer.push make_event
        expect { perform }.not_to change { buffer.length }
      end

      it 'does not change the subscription' do
        buffer.push make_event
        expect { perform }.not_to change { subscription.length }
      end
    end

    context 'when the subscription is empty' do
      include_examples 'doing nothing'
    end

    context 'when the subscription has an event' do
      before { 2.times { subscription.push make_event } }

      context 'and the buffer is not full' do
        before { buffer.push make_event }

        it 'adds to the buffer' do
          expect { perform }.to change { buffer.length }.by(2)
        end

        it 'removes from the subscription' do
          expect { perform }.to change { subscription.length }.by(-2)
        end

        it 'buffers in order' do
          while buffer.pop ; end
          perform
          expect(buffer.peek.url).to end_with('/1')
        end
      end

      context 'and the buffer is full' do
        before { 3.times { buffer.push make_event } }
        include_examples 'doing nothing'
      end
    end
  end
end
