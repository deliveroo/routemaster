require 'spec_helper'
require 'dogapi'
require 'routemaster/application'
require 'routemaster/services/deliver_metric'
require 'routemaster/services/metrics_collectors/datadog'
require 'core_ext/silence_stream'

describe Routemaster::Services::MetricsCollectors::Datadog do

  describe '#perform' do
    subject { described_class.instance }
    let(:name) { "test.metric" }
    let(:value) { 10.5 }
    let(:tags) { ["app:routemaster","env:test"] }
    let(:client) { double(Dogapi::Client) }

    before { Singleton.__init__(described_class) }

    context 'when the api key is missing' do
      it 'should raise exception' do
        STDERR.silence_stream do
          expect { subject.process(error) }.to raise_error(SystemExit)
        end
      end
    end

    context 'when the configuration is set properly' do
      before { ENV['DATADOG_API_KEY'] = 'api_key_super_secret' }
      before { ENV['DATADOG_APP_KEY'] = 'api_key_super_secret_app' }
      after  { ENV.delete 'DATADOG_API_KEY' }
      after  { ENV.delete 'DATADOG_APP_KEY' }

      it 'should send a metric to datadog' do
        expect(Dogapi::Client).to receive(:new).and_return(client)
        expect(client)
          .to receive(:emit_point)
          .with(
            "test.metric",
            10.5,
            {:tags=>["app:routemaster", "env:test"]}
          )

        subject.perform(name, value, tags)
      end
    end
  end
end
