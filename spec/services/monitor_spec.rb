require 'spec_helper'
require 'routemaster/services/monitor'

describe Routemaster::Services::Monitor do
  let(:deliver) { instance_double 'Routemaster::Services::DeliverMetric' }

  before do
    Routemaster::Models::Subscriber.new(subscriber: 'alice')
    Routemaster::Models::Subscriber.new(subscriber: 'bob')
    allow_any_instance_of(Routemaster::Models::Queue).to receive(:length).and_return(1337)
    allow_any_instance_of(Routemaster::Models::Queue).to receive(:staleness).and_return(7331)
  end

  it 'dispatches metrics' do
    expect_any_instance_of(Routemaster::Services::DeliverMetric).
      to receive(:call).
      with('subscriber.queue.size', 1337, %w[env:test app:routemaster subscriber:alice])
    expect_any_instance_of(Routemaster::Services::DeliverMetric).
      to receive(:call).
      with('subscriber.queue.size', 1337, %w[env:test app:routemaster subscriber:bob])
    expect_any_instance_of(Routemaster::Services::DeliverMetric).
      to receive(:call).
      with('subscriber.queue.staleness', 7331, %w[env:test app:routemaster subscriber:alice])
    expect_any_instance_of(Routemaster::Services::DeliverMetric).
      to receive(:call).
      with('subscriber.queue.staleness', 7331, %w[env:test app:routemaster subscriber:bob])

    subject.call
  end
end
