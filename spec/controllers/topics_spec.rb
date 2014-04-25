require 'spec_helper'
require 'routemaster/controllers/topics'
require 'spec/support/rack_test'
require 'spec/support/persistence'

describe Routemaster::Controllers::Topics do
  let(:uid) { 'joe-user' }
  let(:app) { AuthenticatedApp.new(described_class, uid: uid) }
  let(:topic_name) { 'widgets' }
  let(:topic) { Routemaster::Models::Topic.new(name: topic_name, publisher: uid) }

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
      perform
      last_event = topic.last_event
      expect(last_event).not_to be_nil
      expect(last_event.type).to eq('create')
      expect(last_event.url).to  eq('https://example.com/widgets/123')
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
        Routemaster::Models::Topic.new(name: 'widgets', publisher: 'bob-user')
      end

      it 'returns unauthorized' do
        perform
        expect(last_response).to be_forbidden
      end
    end
  end
end
