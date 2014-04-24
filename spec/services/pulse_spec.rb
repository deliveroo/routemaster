require 'spec_helper'
require 'routemaster/services/pulse'

describe Routemaster::Services::Pulse do
  describe '#run' do
    let(:perform) { subject.run }

    it 'returns true' do
      expect(perform).to be_true
    end

    context 'when Redis is down' do
      before do
        ENV['EXCEPTION_SERVICE'] = 'DummyService'
        Redis.any_instance.stub(:ping).and_raise(Redis::CannotConnectError)
      end

      it 'returns false' do
        expect(perform).to be_false
      end

      it 'logs the exception' do
        DummyService.should_receive(:process)
        perform
      end
    end

    context 'when RabbitMQ is down' do
      it 'returns false'
    end
  end
end
