require 'spec_helper'
require 'routemaster/services/thread_group'

describe Routemaster::Services::ThreadGroup do
  subject { described_class.new }

  after { subject.stop.wait }
  around { |ex| Timeout.timeout(1) { ex.run } }

  let(:q) { Queue.new }

  describe '#add' do
    it 'schedules the callables' do
      subject.add( -> { q.push :foo }, name: 'foo')
      expect(q.pop).to eq(:foo)
    end
  end

  describe 'error handling' do
    it 'stops other threads' do
      subject.add( -> { sleep 50e-3 }, name: 'foo')
      subject.add( -> { raise 'oh noes' }, name: 'bar')
      subject.wait # this would timeout if the 'foo' thread didn't stop
    end
  end
end
