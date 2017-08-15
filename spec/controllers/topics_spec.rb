require 'spec_helper'
require 'routemaster/controllers/topics'
require 'spec/support/rack_test'
require 'spec/support/persistence'

describe Routemaster::Controllers::Topics, type: :controller do
  let(:uid) { 'joe-user' }
  let(:app) { described_class.new }
  let(:topic_name) { 'widgets' }
  let(:topic) { Routemaster::Models::Topic.find_or_create!(name: topic_name, publisher: uid) }

  before do
    Routemaster::Models::ClientToken.create! name: uid, token: uid
    authorize uid, 'x'
  end

  describe 'POST /topics/:name' do
    let(:perform) { post "/topics/#{topic_name}", payload, 'CONTENT_TYPE' => 'application/json' }
    let(:data) {{
      type: 'create',
      url:  'https://example.com/widgets/123'
    }}
    let(:payload) { data.to_json }

    it 'responds ok' do
      perform
      expect(last_response).to be_ok
    end

    it 'pushes the event' do
      batch = double 'batch', promote: nil
      ingest = double 'ingest'
      expect(ingest).to receive(:call).and_return(batch)
      expect(Routemaster::Services::Ingest).to receive(:new) { |options|
        topic = options[:topic]
        event = options[:event]
        expect(topic.name).to eq(topic_name)
        expect(event.type).to eq('create')
        expect(event.url).to  eq('https://example.com/widgets/123')
      }.and_return(ingest)
      perform
    end

    context 'when supplying a timestamp' do
      let(:data) {{
        type: 'create',
        url:  'https://example.com/widgets/123',
        timestamp: Time.now.to_i * 1e3
      }}

      it 'responds ok' do
        perform
        expect(last_response).to be_ok
      end
    end

    context 'when supplying a null timestamp' do
      let(:data) {{
        type: 'create',
        url:  'https://example.com/widgets/123',
        timestamp: nil
      }}

      it 'responds ok' do
        perform
        expect(last_response).to be_ok
      end
    end

    context 'when supplying a future timestamp' do
      let(:data) {{
        type: 'create',
        url:  'https://example.com/widgets/123',
        timestamp: (Time.now.to_i * 1e3) + 5000
      }}

      it 'returns 400' do
        perform
        expect(last_response.status).to eq(400)
      end
    end

    context 'when supplying a data payload' do
      let(:event_payload) {{
        'lat' => 45.1882728, 'lon' => 5.723756
      }}
      let(:data) {{
        type: 'create',
        url:  'https://example.com/widgets/123',
        data:  event_payload,
      }}

      it { expect(perform).to be_ok }

      context 'with too much data' do
        let(:event_payload) { SecureRandom.hex(32) }

        it { expect(perform).to be_bad_request }
      end
    end

    describe '(error cases)' do
      it 'returns 400 on bad JSON' do
        payload.replace('whatever')
        perform
        expect(last_response.status).to eq(400)
      end

      it 'returns 400 on bad topic' do
        topic_name.replace 'oh_my_gentle_jeezuss1234toolong'
        perform
        expect(last_response.status).to eq(400)
      end

      it 'returns 400  on bad event type' do
        data[:type] = 'whatever'
        perform
        expect(last_response.status).to eq(400)
      end
    end

    context 'when the topic is claimed' do
      before do
        Routemaster::Models::Topic.find_or_create!(name: 'widgets', publisher: 'bob-user')
      end

      it 'returns unauthorized' do
        perform
        expect(last_response).to be_forbidden
      end
    end
  end

  describe 'GET /topics' do
    let(:uid) { 'joe-user' }
    let(:app) { described_class.new }

    let(:perform) { get "/topics" }

    before do
      Routemaster::Models::Topic.find_or_create!(name: 'widgets', publisher: uid)
      Routemaster::Models::Topic.find_or_create!(name: 'dongles', publisher: uid)
    end

    it 'responds' do
      perform
      expect(last_response.status).to eq(200)
    end

    it 'lists all available topics' do
      perform
      response = JSON last_response.body
      expect(response).to include(
        {
          "name" => 'widgets',
          "publisher" => 'joe-user',
          "events" => 0
        }
      )
      expect(response).to include(
        {
          "name" => 'dongles',
          "publisher" => 'joe-user',
          "events" => 0
        }
      )
    end
  end

  describe 'DELETE /topic/:name' do
    let(:perform) { delete "/topics/#{topic_name}" }

    context 'at rest' do
      it 'returns 404' do
        expect(perform.status).to eq(404)
      end
    end

    context 'with a topic' do
      before { topic }

      it 'returns 204' do
        expect(perform.status).to eq(204)
      end

      it 'deletes the topic' do
        expect { perform }.to change { 
          Routemaster::Models::Topic.find(topic_name)&.name
        }.to(nil)
      end
    end
  end

end
