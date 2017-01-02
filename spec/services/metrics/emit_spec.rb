require 'spec_helper'
require 'spec/support/env'
require 'routemaster/services/metrics/emit'
require 'routemaster/services/metrics/print_adapter'
require 'routemaster/services/metrics/datadog_adapter'

describe Routemaster::Services::Metrics::Emit do
  shared_examples 'delivery' do
    before { ENV['METRIC_COLLECTION_SERVICE'] = name }

    it 'initializes safely' do
      expect { subject }.not_to raise_error
    end

    it 'dispatches to the delivery service' do 
      expect(service).to receive(:gauge).with('my.metric', 1234, ['foo:bar'])
      subject.gauge('my.metric', 1234, ['foo:bar'])
    end
  end
  
  context 'when using logs' do
    let(:service) { Routemaster::Services::Metrics::PrintAdapter.instance }
    let(:name) { 'print' }

    include_examples 'delivery'
  end

  context 'when using datadog' do
    let(:service) { Routemaster::Services::Metrics::DatadogAdapter.instance }
    let(:name) { 'datadog' }

    before do
      ENV['DATADOG_API_KEY'] = 'foo'
      ENV['DATADOG_APP_KEY'] = 'bar'
    end

    include_examples 'delivery'
  end

end
