require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/services/ticker'
require 'routemaster/models/queue'

describe Routemaster::Services::Ticker do
  let(:q) { Routemaster::Models::Queue.new(name: 'foo') }
  subject { described_class.new queue: q, name: 'tick', every: 42 }

  it 'enqueues a job' do
    expect { subject.call }.to change { q.length }.by(1)
  end
end
