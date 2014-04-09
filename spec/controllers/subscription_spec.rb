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
    let(:perform) { post '/subscription', payload.to_json, 'CONTENT_TYPE' => 'application/json' }

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

    it 'rejects bad callbacks'
    it 'rejects non-JSON bodies'
    it 'accepts an optional "timeout"'
    it 'accepts an optional "max"'
  end
end
