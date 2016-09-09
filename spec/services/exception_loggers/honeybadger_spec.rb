require 'spec_helper'
require 'spec/support/env'
require 'routemaster/application'
require 'routemaster/mixins/log'
require 'routemaster/mixins/log_exception'
require 'routemaster/services/exception_loggers/honeybadger'
require 'core_ext/silence_stream'

describe Routemaster::Services::ExceptionLoggers::Honeybadger do
  # predeclare so we can test loading
  ::Honeybadger ||= Module.new

  describe '#process' do
    subject { described_class.instance }
    let(:error) {  StandardError.new('error message') }

    before { Singleton.__init__(described_class) }

    context 'when the api key is missing' do
      before { ENV.delete 'HONEYBADGER_API_KEY' }

      it 'should raise exception' do
        STDERR.silence_stream do
          expect { subject.process(error) }.to raise_error(SystemExit)
        end
      end
    end

    context 'when the configuration is set properly' do
      it 'should send a notification to Honeybadger' do
        expect(Honeybadger).to receive(:notify).with(error)

        subject.process(error)
      end
    end
  end
end
