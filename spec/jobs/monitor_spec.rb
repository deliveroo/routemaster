require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/jobs/monitor'

describe Routemaster::Jobs::Monitor do
  let(:dispatcher) { instance_double 'Routemaster::Services::DeliverMetric' }
  subject { described_class.new(dispatcher: dispatcher) }

  before do
    @events = []
    allow(dispatcher).to receive(:call) do |*args|
      @events << args
    end

    allow(Routemaster::Models::Batch).to receive(:counters).and_return(
      batches: {
        'alice' => 1,
        'bob'   => 4,
      },
      events: {
        'alice' => 12,
        'bob'   => 42,
      }
    )
  
    [
      Routemaster::Models::Job.new(name: 'null', args: 1, run_at: nil),
      Routemaster::Models::Job.new(name: 'null', args: 2, run_at: Routemaster.now + 1000),
      Routemaster::Models::Job.new(name: 'null', args: 3, run_at: Routemaster.now),
    ].each do |j|
      Routemaster::Models::Queue.new(name: 'foo').push(j)
    end
  end

  it 'dispatches metrics' do
    subject.call

    expect(@events).to include(['subscriber.queue.batches', 1,  array_including('subscriber:alice')])
    expect(@events).to include(['subscriber.queue.batches', 4,  array_including('subscriber:bob')])
    expect(@events).to include(['subscriber.queue.events',  12, array_including('subscriber:alice')])
    expect(@events).to include(['subscriber.queue.events',  42, array_including('subscriber:bob')])

    expect(@events).to include(['jobs.count', 2, %w[env:test app:routemaster queue:foo status:instant]])
    expect(@events).to include(['jobs.count', 1, %w[env:test app:routemaster queue:foo status:scheduled]])
  end
end
