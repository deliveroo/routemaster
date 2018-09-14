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
    it 'should report necessary metrics with appropriate tags' do
      subject.call

      base_tags = [
        'app:routemaster-dev',
        'env:test',
        'hopper_service_name:null',
        'hopper_app_name:null',
      ]

      expect(@gauges).to include(['subscriber.queue.batches', 1, array_including('subscriber:alice', *base_tags)])
      expect(@gauges).to include(['subscriber.queue.batches', 4, array_including('subscriber:bob', *base_tags)])
      expect(@gauges).to include(['subscriber.queue.events', 12, array_including('subscriber:alice', *base_tags)])
      expect(@gauges).to include(['subscriber.queue.events', 42, array_including('subscriber:bob', *base_tags)])

      expect(@gauges).to include(['jobs.count', 2, array_including(['queue:main', 'status:instant', *base_tags])])
      expect(@gauges).to include(['jobs.count', 1, array_including(['queue:main', 'status:scheduled', *base_tags])])

      expect(@gauges).to include(['redis.bytes_used', a_kind_of(Integer), array_including(*base_tags)])
      expect(@gauges).to include(['redis.low_mark', a_kind_of(Integer), array_including(*base_tags)])
      expect(@gauges).to include(['redis.high_mark', a_kind_of(Integer), array_including(*base_tags)])
    end
  end

  describe 'dispatches counters' do
    before do
      Routemaster::Models::Counters.instance.incr(:foo, bar: :baz).flush
      subject.call
    end

    it { expect(@counters).to include(['redis.used_cpu_user', a_kind_of(Integer), a_kind_of(Array)]) }
    it { expect(@counters).to include(['foo', 1, array_including('bar:baz')]) }
  end


  context 'when monitoring fails' do
    before do
      # Raise on the injected Metrics::Emit double because it's a convenient public
      # entry point, but we actually care about errors raised when the Datdog
      # adapter flushes the batched metrics over the network. The Datadog adapter
      # is a private implementation detail though, not used in the test env, and
      # we should really test against the higher level public class.
      allow(dispatcher).to receive(:gauge).and_raise(Net::OpenTimeout)
    end

    it 'raises a Retry error' do
      expect {
        subject.call
      }.to raise_error(Routemaster::Models::Queue::Retry)
    end

    it 'sets a retry delay' do
      begin
        subject.call
      rescue => error
        @error = error
      end
      expect(@error.delay).to eql 1_000
    end
  end
end
