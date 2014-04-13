require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/events'
require 'routemaster/services/watch'
require 'routemaster/models/subscription'

describe Routemaster::Services::Watch do
  let(:subscription) { Routemaster::Models::Subscription.new(subscriber: 'alice')  }

  def subject(max_events = nil) 
    @subject ||= described_class.new(max_events)
  end

  def queue_event
    subscription.queue.publish(make_event.dump) 
  end

  def queue_kill_event
    subscription.queue.publish('kill')
  end

  def perform(max_events = nil)
    subject(max_events).run
  end

  def kill_after(seconds)
    Thread.new { sleep seconds; subject.stop }
  end

  describe '#stop' do
    shared_examples 'an execution stopper' do
      it 'stops execution' do
        Thread.new { sleep 1 ; subject.stop }
        thread = Thread.new { subject.run }
        sleep 2
        expect(thread.status).to be_false
      end
    end

    context 'without subscriptions' do
      it_behaves_like 'an execution stopper'
    end

    context 'with subscriptions' do
      before { subscription }
      it_behaves_like 'an execution stopper'
    end
  end

  describe '#run' do
    let(:delivery) { double('delivery', run: true) }
    
    before do
      allow(Routemaster::Services::Deliver).to receive(:new) { |sub, buf|
        delivery.stub(_sub: sub, _buf: buf)
      }.and_return(delivery)
    end

    it 'passes when no messages are queued' do
      subscription
      kill_after(2)
      perform
    end

    it 'attempts delivery once per event' do
      expect(delivery).to receive(:run).exactly(3).times
      3.times { queue_event }
      perform(3)
    end

    it 'passes batches to delivery' do
      delivery.stub run: false
      5.times { queue_event }
      perform(5)
      expect(delivery._buf.length).to eq(5)
    end

    it 'passes a new batch once accepted by delivery' do
      allow(delivery).to receive(:run).and_return(true, false, false)
      3.times { queue_event }
      perform(3)
      expect(delivery._buf.length).to eq(2)
    end

    it 'passes events in order' do
      delivery.stub run: false
      5.times { queue_event }
      perform(5)
      expect(delivery._buf.first.url).to end_with('/1')
      expect(delivery._buf.last.url).to  end_with('/5')
    end

    it 'keeps events when delivery fails' do
      allow(delivery).to receive(:run) do 
        if @already_ran
          false
        else
          @already_ran = true
          raise Routemaster::Services::Deliver::CantDeliver
        end
      end

      3.times { queue_event } 
      perform(3)
      expect(delivery._buf.length).to eq(3)
    end

    it 'stops on a kill event'
    it 'removes bad events from the queue'
  end
end
