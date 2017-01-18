require 'spec_helper'
require 'spec/support/integration'

describe 'Support processes for acceptance testing', slow: true do
  let(:processes) { Acceptance::ProcessLibrary.new }
  before { WebMock.disable! }

  shared_examples 'start and stop' do
    before { subject.start }
    after  { subject.terminate }

    it 'starts cleanly' do
      subject.wait_start
    end

    it 'stops cleanly' do
      subject.wait_start
      subject.stop.wait_stop
    end
  end

  context 'watch worker' do
    subject { processes.watch }
    include_examples 'start and stop'
  end

  context 'web worker' do
    subject { processes.web }
    include_examples 'start and stop'
  end

  context 'client worker' do
    subject { processes.client }
    include_examples 'start and stop'
  end

  context 'server tunnel' do
    subject { processes.server_tunnel }
    include_examples 'start and stop'
  end

  context 'client tunnel' do
    subject { processes.client_tunnel }
    include_examples 'start and stop'
  end
end

