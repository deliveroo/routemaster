require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/counters'
require 'routemaster/jobs/scrub_workers'
require 'routemaster/models/queue'
require 'routemaster/models/job'
require 'routemaster/services/worker'

describe Routemaster::Jobs::ScrubWorkers do

  let(:queue) { Routemaster::Models::Queue.new(name: 'foo') }
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

  context 'when the worker was last active' do
    context 'just now' do
      it 'does not clear the worker' do
        expect { subject.call }.not_to change { worker.last_at }
      end

      it 'does not increments workers.scrubbed' do
        expect { subject.call }.not_to change {
          get_counter('workers.scrubbed')
        }
      end
    end

    context 'a while ago' do
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
end

