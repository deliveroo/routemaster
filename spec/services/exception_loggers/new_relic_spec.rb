require 'spec_helper'
require 'spec/support/env'
require 'routemaster/application'
require 'routemaster/mixins/log'
require 'routemaster/mixins/log_exception'
require 'routemaster/services/exception_loggers/new_relic'
require 'core_ext/silence_stream'
require 'newrelic_rpm'

describe Routemaster::Services::ExceptionLoggers::NewRelic do
  subject(:instance) { described_class.instance }

  describe '#process' do
    subject(:process) { instance.process(error) }
    let(:error) { StandardError.new('error message') }

    around do |example|
      Singleton.__init__(described_class)
      STDERR.silence_stream { example.run }
    end

    context 'when the api key is missing' do
      before { ENV.delete 'NEW_RELIC_LICENSE_KEY' }

      it 'should raise exception' do
        expect { process }.to raise_error(SystemExit)
      end
    end

    context 'when the configuration is set properly' do
      before { ENV['NEW_RELIC_LICENSE_KEY'] = 'key' }

      it 'should send a notification to NewRelic' do
        expect(::NewRelic::Agent).to receive(:notice_error).with(error)

        process
      end
    end
  end
end
