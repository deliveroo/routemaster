require 'spec_helper'
require 'spec/support/integration'
require 'spec/support/persistence'
require 'routemaster'

describe 'Process counters', slow:true do
  let(:processes) { Acceptance::ProcessLibrary.new }
  before { WebMock.disable! }

  before { ENV['ROUTEMASTER_COUNTER_FLUSH_INTERVAL'] = '1' }

  shared_examples 'start and stop' do |type_tag, count|
    let(:counters) { Routemaster.counters.dump }
    before { subject.start }
    after  { subject.terminate }

    it 'starts cleanly' do
      subject.wait_start
      sleep 2 # enough time for the flusher thread to trigger
      expect(counters[['process', %w[status start], type_tag]]).to eq(count)
    end

    it 'stops cleanly' do
      subject.wait_start
      subject.stop.wait_stop
      expect(counters[['process', %w[status start], type_tag]]).to eq(count)
      expect(counters[['process', %w[status stop],  type_tag]]).to eq(count)
    end
  end

  context 'watch worker' do
    subject { processes.watch }
    include_examples 'start and stop', %w[type worker], 1
  end

  context 'web worker' do
    subject { processes.web }
    include_examples 'start and stop', %w[type web], 2
  end
end

