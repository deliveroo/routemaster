require 'spec_helper'
require 'raven'
require 'routemaster/application'
require 'routemaster/mixins/log'
require 'routemaster/mixins/log_exception'
require 'routemaster/services/exception_loggers/sentry'

describe Routemaster::Services::ExceptionLoggers::Sentry do

  describe '#process' do

    let(:subject) { described_class.instance }

    before do
      ENV['EXCEPTION_SERVICE_URL']='http://test.host'
    end

    it 'should work' do
      error = StandardError.new('error message')
      expect(Raven::Event).to receive(:capture_exception)
      subject.process(error)
    end

  end

end
