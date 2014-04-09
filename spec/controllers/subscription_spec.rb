require 'spec_helper'
require 'routemaster/controllers/subscription'
require 'spec/support/rack_test'
require 'spec/support/persistence'

describe Routemaster::Controllers::Subscription do
  let(:uid) { 'charlie' }
  let(:app) { AuthenticatedApp.new(described_class, uid: uid) }

  describe 'post /subscription' do
    let(:payload) {{
      topics:   %w(widgets),
      callback: 'https://app.example.com/events',
      uuid:     'alice'
    }}
    let(:raw_payload) { payload.to_json }
    let(:perform) { post '/subscription', raw_payload, 'CONTENT_TYPE' => 'application/json' }
    let(:subscription) { Routemaster::Models::Subscription.new(subscriber: 'charlie') }

    before do
      Routemaster::Models::Topic.new(name: 'widgets', publisher: 'bob')
    end

    it 'returns 204 with correct payload' do
      perform
      expect(last_response.status).to eq(204)
    end
    
    it 'rejects unknown topics' do
      payload[:topics] = %w(grizzlis)
      perform
      expect(last_response).to be_not_found
    end

    it 'rejects bad topic lists' do
      payload[:topics] = 1234
      perform
      expect(last_response).to be_bad_request
    end

    it 'rejects bad callbacks' do
      payload[:callback] = 'http://example.com' # no SSL
      perform
      expect(last_response).to be_bad_request
    end

    it 'rejects non-JSON bodies' do
      raw_payload.replace 'nonsense'
      perform
      expect(last_response).to be_bad_request
    end

    it 'accepts an optional "timeout"' do
      payload[:timeout] = 500
      perform
      expect(last_response.status).to eq(204)
    end

    it 'accepts an optional "max"' do
      payload[:max] = 500
      perform
      expect(last_response.status).to eq(204)
    end

    it 'sets the subscription callback' do
      perform
      expect(subscription.callback).to eq('https://app.example.com/events')
    end

    it 'sets the subscription uuid' do
      perform
      expect(subscription.uuid).to eq('alice')
    end

    it 'sets the subscription timeout' do
      payload[:timeout] = 675
      perform
      expect(subscription.timeout).to eq(675)
    end

    it 'sets the subscription max' do
      payload[:max] = 512
      perform
      expect(subscription.max_events).to eq(512)
    end
  end
end
