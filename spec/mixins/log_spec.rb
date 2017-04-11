require 'spec_helper'
require 'routemaster/mixins/log'

describe Routemaster::Mixins::Log do
  include described_class

  describe "#_log" do
    let(:logger) { instance_double(Logger) }

    context "when log level is valid" do
      before do
        ENV['ROUTEMASTER_LOG_LEVEL'] = 'INFO'
        allow(Logger).to receive(:new).and_return(logger)
      end

      it 'does not warn log message' do
        expect(logger).to_not receive(:warn).with("log level INFO is invalid, defaulting to INFO")
      end
    end

    context "when log level is invalid" do
      before do
        ENV['ROUTEMASTER_LOG_LEVEL'] = 'FOO'
        allow(Logger).to receive(:new).and_return(logger)
      end

      it 'does not warn log message' do
        expect(logger).to receive(:warn).with("log level FOO is invalid, defaulting to INFO")
      end
    end

  end
end
