require 'spec_helper'
require 'routemaster/controllers/subscription'
require 'spec/support/rack_test'
require 'spec/support/persistence'
require 'json'

describe Routemaster::Controllers::Subscription do
  let(:uid) { 'charlie' }
  let(:app) { AuthenticatedApp.new(described_class, uid: uid) }

  describe 'GET /subscriptions' do

    let(:topic) do
      Routemaster::Models::Topic.new(
        name: 'widget',
        publisher: 'demo'
      )
    end

    let(:subscription) do
      Routemaster::Models::Subscription.new(
        subscriber: 'charlie'
      )
    end

    let(:perform) { get "/subscriptions" }

    it 'responds' do
      perform
      expect(last_response.status).to eq(200)
    end

    it 'lists all subscriptions with required data points' do
      topic.subscribers.add(subscription)
      allow(Routemaster::Models::Subscription)
        .to receive(:each).and_yield(subscription)
      allow(subscription)
        .to receive(:age_of_oldest_message).and_return(1000)
      allow(subscription)
        .to receive(:all_topics_count).and_return(100)
      expect(subscription)
        .to receive_message_chain("queue.message_count").and_return(50)

      perform
      resp = JSON(last_response.body)

      expect(resp)
        .to eql([{
          "subscriber" => "charlie",
          "callback"   => nil,
          "topics"     => ["widget"],
          "events"     => {
            "sent"   => 100,
            "queued" => 50,
            "oldest" => 1000
          }
        }]
      )
    end
  end

  describe 'post /subscription' do
    let(:payload) {{
      topics:   %w(widgets),
      callback: 'https://app.example.com/events',
      uuid:     'alice'
    }}
    let(:raw_payload) { payload.to_json }
    let(:perform) do
      post '/subscription', raw_payload, 'CONTENT_TYPE' => 'application/json'
    end
    let(:subscription) do
      Routemaster::Models::Subscription.new(subscriber: 'charlie')
    end

    before do
      Routemaster::Models::Topic.new(name: 'widgets', publisher: 'bob')
    end

    it 'returns 204 with correct payload' do
      perform
      expect(last_response.status).to eq(204)
    end

    it 'acceptc unknown topics' do
      payload[:topics] = %w(grizzlis)
      perform
      expect(last_response.status).to eq(204)
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
