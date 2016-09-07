require 'spec_helper'
require 'spec/support/env'
require 'routemaster/services/pulse'
require 'spec/support/dummy'
require 'spec/support/env'

describe Routemaster::Services::Pulse do
  describe '#run' do
    let(:perform) { subject.run }

    before do
      ENV['EXCEPTION_SERVICE'] = 'dummy'
    end

    it 'returns true' do
      expect(perform).to eq(true)
    end

    shared_examples 'logging' do
      it 'logs exception' do
        expect(Routemaster::Services::ExceptionLoggers::Dummy.instance).to receive(:process)
        perform
      end
    end

    context 'when Redis is down' do
      before do
        allow_any_instance_of(Redis).to receive(:ping).and_raise(Redis::CannotConnectError)
      end

      it 'returns false' do
        expect(perform).to eq(false)
      end

      include_examples 'logging'
    end
  end
end
