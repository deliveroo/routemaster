require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/jobs/monitor'
require 'routemaster/services/metrics/emit'

describe Routemaster::Jobs::Monitor do
  let(:dispatcher) { instance_double Routemaster::Services::Metrics::Emit }
  subject { described_class.new(dispatcher: dispatcher) }

  before do
    @gauges = []
    @counters = []
    allow(dispatcher).to receive(:gauge)   { |*args| @gauges   << args }
    allow(dispatcher).to receive(:counter) { |*args| @counters << args }
    allow(dispatcher).to receive(:batched).and_yield

    allow(Routemaster::Models::Batch).to receive(:gauges).and_return(
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
      Routemaster::Models::Queue::MAIN.push(j)
    end
  end

  describe 'dispatches gauges' do
    before { subject.call }

    it { expect(@gauges).to include(['subscriber.queue.batches',  1, array_including('subscriber:alice')]) }
    it { expect(@gauges).to include(['subscriber.queue.batches',  4, array_including('subscriber:bob')]) }
    it { expect(@gauges).to include(['subscriber.queue.events',  12, array_including('subscriber:alice')]) }
    it { expect(@gauges).to include(['subscriber.queue.events',  42, array_including('subscriber:bob')]) }

    it { expect(@gauges).to include(['jobs.count', 2, array_including(%w[queue:main status:instant])]) }
    it { expect(@gauges).to include(['jobs.count', 1, array_including(%w[queue:main status:scheduled])]) }

    it { expect(@gauges).to include(['redis.bytes_used',    a_kind_of(Fixnum), a_kind_of(Array)]) }
    it { expect(@gauges).to include(['redis.low_mark',      a_kind_of(Fixnum), a_kind_of(Array)]) }
    it { expect(@gauges).to include(['redis.high_mark',     a_kind_of(Fixnum), a_kind_of(Array)]) }
  end

  describe 'dispatches counters' do
    before do 
      Routemaster::Models::Counters.instance.incr(:foo, bar: :baz).flush
      subject.call
    end

    it { expect(@counters).to include(['redis.used_cpu_user', a_kind_of(Integer), a_kind_of(Array)]) }
    it { expect(@counters).to include(['foo', 1, array_including('bar:baz')]) }
  end
end
