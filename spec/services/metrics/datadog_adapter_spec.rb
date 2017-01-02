require 'spec_helper'
require 'spec/support/env'
require 'dogapi'
require 'routemaster/application'
require 'routemaster/services/metrics/emit'
require 'routemaster/services/metrics/datadog_adapter'
require 'core_ext/silence_stream'

describe Routemaster::Services::Metrics::DatadogAdapter do

  describe '#perform' do
    subject { described_class.instance }
    let(:name) { 'test.metric' }
    let(:value) { 10.5 }
    let(:tags) { %w[app:routemaster env:test] }
    let(:client) { instance_double(Dogapi::Client) }

    # forcibly reset the singleton
    before { Singleton.__init__(described_class) }

    context 'when the api key is missing' do
      it 'should raise exception' do
        STDERR.silence_stream do
          expect { subject }.to raise_error(SystemExit)
        end
      end
    end

    context 'when the configuration is set properly' do
      before { ENV['DATADOG_API_KEY'] = 'api_key_super_secret' }
      before { ENV['DATADOG_APP_KEY'] = 'api_key_super_secret_app' }

      it 'should send a metric to datadog' do
        expect_any_instance_of(Dogapi::Client).
          to receive(:emit_point).
          with(
            'test.metric',
            10.5,
            tags: %w[app:routemaster env:test],
            type: 'gauge'
          )

        subject.gauge(name, value, tags)
      end
    end
  end
end
