require 'spec_helper'
require 'spec/support/integration'
require 'spec/support/persistence'
require 'spec/support/counters'
require 'routemaster'

describe 'Process counters', slow:true do
  let(:processes) { Acceptance::ProcessLibrary.new }
  before { WebMock.disable! }

  before { ENV['ROUTEMASTER_COUNTER_FLUSH_INTERVAL'] = '1' }

  shared_examples 'start and stop' do |count, type_tag|
    before { subject.start }
    after  { subject.terminate }

    it 'starts cleanly' do
      subject.wait_start
      sleep 2 # enough time for the flusher thread to trigger
      expect(get_counter('process', type_tag.merge(status: 'start'))).to eq(count)
      # FIXME: use wait_log to avoid the sleeping (proper integration)
    end

    it 'stops cleanly' do
      subject.wait_start
      subject.stop.wait_stop
      expect(get_counter('process', type_tag.merge(status: 'stop'))).to eq(count)
    end
  end

  context 'watch worker' do
    subject { processes.watch }
    include_examples 'start and stop', 1, type: 'worker'
  end

  context 'web worker' do
    subject { processes.web }
    include_examples 'start and stop', 2, type: 'web'
  end
end

