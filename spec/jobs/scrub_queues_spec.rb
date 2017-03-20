require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/jobs'
require 'routemaster/jobs/scrub_queues'
require 'routemaster/models/queue'
require 'routemaster/models/job'
require 'routemaster/services/worker'

describe Routemaster::Jobs::ScrubQueues do

  let(:queue) { Routemaster::Models::Queue::MAIN }
  let(:job) { Routemaster::Models::Job.new(name: 'fail') }
  let(:worker) { Routemaster::Services::Worker.new(id: 'flakey', queue: queue) }

  let(:max_age) { 10_000 }

  subject { described_class.new(max_age: max_age) }

  before do
    queue.push(job)
  end

  context 'the worker' do
    it 'fails the job' do
      expect { worker.call }.to raise_error(RuntimeError)
    end

    it 'empties the queue' do
      expect { worker.call rescue RuntimeError }.to change { queue.length }.by(-1)
    end
  end

  context 'when job has failed' do
    before { worker.call rescue RuntimeError }

    shared_examples_for 'successfully scrubs' do
      context 'just now' do
        it 'does not re-queue the job' do
          expect { subject.call }.not_to change { queue.length }
        end
      end

      context 'a while ago' do
        before do
          allow(Routemaster).to receive(:now) { Time.now.to_i * 1000 + 2*max_age }
        end

        it 're-queues the job' do
          expect { subject.call }.to change { queue.length }.by(1)
        end
      end
    end

    it_behaves_like 'successfully scrubs'

    describe 'when the worker shuts down while we are scrubbing and its metadata is cleared' do
      before do
        allow_any_instance_of(Routemaster::Services::Worker).to receive(:last_at).and_wrap_original do |m, *args|
          data = m.call(*args)
          m.receiver.cleanup
          data
        end
      end

      it_behaves_like 'successfully scrubs'
    end
  end
end
