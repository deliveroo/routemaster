require 'spec_helper'
require 'routemaster/services/buffer'
require 'routemaster/models/queue'
require 'spec/support/persistence'
require 'spec/support/events'

describe Routemaster::Services::Buffer do
  let(:queue) { Routemaster::Models::Queue.new(subscriber: 'alice') } 
  let(:buffer) { queue.buffer }
  
  subject { described_class.new(queue) }

  before { queue.max_events = 3 }

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

      it 'does not change the queue' do
        buffer.push make_event
        expect { perform }.not_to change { queue.length }
      end
    end

    context 'when the queue is empty' do
      include_examples 'doing nothing'
    end

    context 'when the queue has an event' do
      before { 2.times { queue.push make_event } }

      context 'and the buffer is not full' do
        before { buffer.push make_event }

        it 'adds to the buffer' do
          expect { perform }.to change { buffer.length }.by(2)
        end

        it 'removes from the queue' do
          expect { perform }.to change { queue.length }.by(-2)
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
