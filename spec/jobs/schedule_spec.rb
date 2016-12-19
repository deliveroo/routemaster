require 'spec_helper'
require 'routemaster/jobs/schedule'

describe Routemaster::Jobs::Schedule do
  it 'performs scheduling on each queue' do
    q1 = double name: 'q1'
    q2 = double name: 'q2'
    allow(Routemaster::Models::Queue).to receive(:each).and_yield(q1).and_yield(q2)
    expect(q1).to receive(:schedule)
    expect(q2).to receive(:schedule)
    subject.call
  end
end
