require 'spec_helper'
require 'routemaster/controllers/subscriber'
require 'spec/support/rack_test'
require 'spec/support/persistence'
require 'json'

describe Routemaster::Controllers::Subscriber, type: :controller do
  let(:uid) { 'charlie' }
  let(:app) { AuthenticatedApp.new(described_class, uid: uid) }

  let(:subscriber) do
    Routemaster::Models::Subscriber.new(name: 'charlie')
  end

  let(:topic) do
    Routemaster::Models::Topic.new(
      name: 'widget',
      publisher: 'bob'
    )
  end

  describe 'GET /subscribers' do
    let(:perform) { get "/subscribers" }

    it 'responds' do
      perform
      expect(last_response.status).to eq(200)
    end

    it 'lists all subscribers with required data points' do
      Routemaster::Models::Subscription.new(subscriber: subscriber, topic: topic).save

      allow(Routemaster::Models::Subscriber)
        .to receive(:each).and_yield(subscriber)
      allow(subscriber)
        .to receive_message_chain('queue.staleness').and_return(1000)
      allow(subscriber)
        .to receive(:all_topics_count).and_return(100)
      expect(subscriber)
        .to receive_message_chain('queue.length').and_return(50)

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

  describe 'post /subscriber' do
    let(:payload) {{
      topics: %w(widgets),
      callback: 'https://app.example.com/events',
      delivery_token: 'alice'
    }}
    let(:raw_payload) { payload.to_json }
    let(:perform) do
      post '/subscriber', raw_payload, 'CONTENT_TYPE' => 'application/json'
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

    it 'sets the subscriber callback' do
      perform
      expect(subscriber.callback).to eq('https://app.example.com/events')
    end

    it 'sets the subscriber delivery_token' do
      perform
      expect(subscriber.delivery_token).to eq('alice')
    end

    it 'sets the subscriber timeout' do
      payload[:timeout] = 675
      perform
      expect(subscriber.timeout).to eq(675)
    end

    it 'sets the subscriber max' do
      payload[:max] = 512
      perform
      expect(subscriber.max_events).to eq(512)
    end
  end


  describe 'DELETE /subscriber' do
    let(:perform) { delete '/subscriber' }

    context 'at rest' do
      it { expect(perform.status).to eq(404) }
    end

    context 'when the subscriber exists' do
      before { subscriber }
      it { expect(perform.status).to eq(204) }
    end
  end


  describe 'DELETE /subscriber/topics/:name' do
    let(:perform) { delete '/subscriber/topics/widget' }

    context 'at rest' do
      it { expect(perform.status).to eq(404) }
    end

    context 'when only the subscriber exists' do
      before { subscriber }
      it { expect(perform.status).to eq(404) }
    end

    context 'when only the topic exists' do
      before { topic }
      it { expect(perform.status).to eq(404) }
    end

    context 'when not subscribed' do
      before { topic ; subscriber }
      it { expect(perform.status).to eq(404) }
    end

    context 'when the subscriber exists' do
      before { Routemaster::Models::Subscription.new(subscriber: subscriber, topic: topic).save }
      it { expect(perform.status).to eq(204) }
    end
  end
end
