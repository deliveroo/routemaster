require 'spec_helper'
require 'routemaster/services/deliver_metric'
require 'spec/support/env'

describe Routemaster::Services::DeliverMetric do
  # predeclare classes so we can actually test loading
  module Routemaster::Services::MetricsCollectors
    Print = Class.new
    Datadog = Class.new
  end

  shared_examples 'delivery' do
    before { ENV['METRIC_COLLECTION_SERVICE'] = name }

    it 'initializes safely' do
      expect { subject }.not_to raise_error
    end

    it 'dispatches to the delivery service' do 
      expect(service).to receive(:perform).with('my.metric', 1234, ['foo:bar'])
      subject.call('my.metric', 1234, ['foo:bar'])
    end
  end
  
  context 'when using logs' do
    let(:service) { Routemaster::Services::MetricsCollectors::Print.instance }
    let(:name) { 'print' }

    include_examples 'delivery'
  end

  context 'when using datadog' do
    let(:service) { Routemaster::Services::MetricsCollectors::Datadog.instance }
    let(:name) { 'datadog' }

    before do
      ENV['DATADOG_API_KEY'] = 'foo'
      ENV['DATADOG_APP_KEY'] = 'bar'
    end

    include_examples 'delivery'
  end

end
