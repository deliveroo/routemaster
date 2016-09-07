require 'spec_helper'
require 'spec/support/env'
require 'raven'
require 'routemaster/application'
require 'routemaster/mixins/log'
require 'routemaster/mixins/log_exception'
require 'routemaster/services/exception_loggers/sentry'
require 'core_ext/silence_stream'

describe Routemaster::Services::ExceptionLoggers::Sentry do

  describe '#process' do
    subject { described_class.instance }
    let(:error) {  StandardError.new('error message') }

    before { Singleton.__init__(described_class) }

    context 'when the api key is missing' do
      it 'should raise exception' do
        STDERR.silence_stream do
          expect { subject.process(error) }.to raise_error(SystemExit)
        end
      end
    end

    context 'when the configuration is set properly' do
      before { ENV['EXCEPTION_SERVICE_URL']='http://test.host' }

      it 'should send a notification to Honeybadger' do
        expect(Raven::Event).to receive(:capture_exception).with(error)

        STDOUT.silence_stream { subject.process(error) }
      end
    end
  end

end
