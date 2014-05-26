require 'spec_helper'
require 'routemaster/services/pulse'
require 'spec/support/dummy'

describe Routemaster::Services::Pulse do
  describe '#run' do
    let(:perform) { subject.run }

    around do |example|
      @old = ENV['EXCEPTION_SERVICE']
      ENV['EXCEPTION_SERVICE'] = 'dummy'
      example.run
      ENV['EXCEPTION_SERVICE'] = @old
    end

    it 'returns true' do
      expect(perform).to be_true
    end

    shared_examples 'logging' do
      it 'logs exception' do
        expect(Routemaster::Services::ExceptionLoggers::Dummy.instance).to receive(:process)
        perform
      end
    end

    context 'when Redis is down' do
      before do
        Redis.any_instance.stub(:ping).and_raise(Redis::CannotConnectError)
      end

      it 'returns false' do
        expect(perform).to be_false
      end

      include_examples 'logging'
    end

    context 'when RabbitMQ is down' do
      before { subject.stub(:bunny).and_raise(Bunny::TCPConnectionFailed.new(1,2,3)) }

      it 'returns false' do
        expect(perform).to be_false
      end

      include_examples 'logging'
    end
  end
end
