require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/counters'
require 'spec/support/jobs'
require 'routemaster/jobs/scrub_workers'
require 'routemaster/models/queue'
require 'routemaster/models/job'
require 'routemaster/services/worker'

describe Routemaster::Jobs::ScrubWorkers do

  let(:queue) { Routemaster::Models::Queue::MAIN }
  let(:job) { Routemaster::Models::Job.new(name: 'null') }
  let(:worker) { Routemaster::Services::Worker.new(id: 'scrappy', queue: queue) }

  let(:max_age) { 10_000 }

  subject { described_class.new(max_age: max_age) }

  before do
    queue.push(job)
    worker.call
  end

  # sanity check
  it { expect(queue.length).to eq(0) }

  shared_examples 'a no-op' do
    it 'does not clear the worker' do
      expect { subject.call }.not_to change { worker.last_at }
    end

    it 'does not increments workers.scrubbed' do
      expect { subject.call }.not_to change {
        get_counter('workers.scrubbed')
      }
    end
  end


  describe 'without race conditions' do
    context 'when the worker was last active just now' do
      it_behaves_like 'a no-op'
    end

    context 'when the worker was last active a while ago' do
      before do
        allow(Routemaster).to receive(:now) { Time.now.to_i * 1000 + 2*max_age }
      end

      it 'clears the worker' do
        expect { subject.call }.to change { worker.last_at }.to(nil)
      end

      it 'increments workers.scrubbed' do
        expect { subject.call }.to change {
          get_counter('workers.scrubbed')
        }.by(1)
      end
    end
  end


  describe 'with concurrent clean up' do
    before do
      allow_any_instance_of(Routemaster::Services::Worker).to receive(:last_at).and_wrap_original do |m, *args|
        # Clean the object's data before calling the method, so that it will return nil.
        # This simulates a race condition where the worker is scrubbed (and it's last_at data
        # is set to nil) while here we are looping and querying the attribute.
        m.receiver.cleanup
        m.call(*args)
      end
    end

    context 'when the worker was last active just now' do
      it_behaves_like 'a no-op'
    end

    context 'when the worker was last active a while ago' do
      before do
        allow(Routemaster).to receive(:now) { Time.now.to_i * 1000 + 2*max_age }
      end

      it_behaves_like 'a no-op'
    end
  end
end

