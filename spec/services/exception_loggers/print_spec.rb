require 'spec_helper'
require 'routemaster/application'
require 'routemaster/mixins/log'
require 'routemaster/mixins/log_exception'
require 'routemaster/services/exception_loggers/print'

describe Routemaster::Services::ExceptionLoggers::Print do

  describe '#process' do

    let(:subject) { described_class.instance }

    it 'should work' do
      error = StandardError.new('error message')
      error.set_backtrace(["backtrace title","backtrace description"])
      expect_any_instance_of(described_class).to receive(:_log_exception)
      subject.process(error)
    end

  end

end
