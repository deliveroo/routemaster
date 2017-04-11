require 'spec_helper'
require 'routemaster/mixins/log'

describe Routemaster::Mixins::Log do
  let(:testing_klass) do
    Class.new do
      include Routemaster::Mixins::Log

      def log
        _log
      end
    end.new
  end

  describe "#_log" do
    let(:logger) { instance_double(Logger).as_null_object }

    before(:each) do
      testing_klass.class.class_variable_set(:@@_logger, nil)
      testing_klass.class.class_variable_set(:@@_log_level, nil)
      allow(Logger).to receive(:new).and_return(logger)
    end

    context "when log level is valid" do
      subject { testing_klass.log }

      before do
        ENV['ROUTEMASTER_LOG_LEVEL'] = 'INFO'
      end

      it 'does not call warn' do
        expect(logger).not_to receive(:warn).with("log level INFO is invalid, defaulting to INFO")
        subject
      end
    end

    context "when log level is invalid" do
      subject { testing_klass.log }

      before do
        ENV['ROUTEMASTER_LOG_LEVEL'] = 'FOO'
      end

      it 'calls warn with log message' do
        expect(logger).to receive(:warn).with("log level FOO is invalid, defaulting to INFO")
        subject
      end
    end

  end
end
