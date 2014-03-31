require 'spec_helper'
require 'routemaster/controllers/topics'
require 'spec/support/rack_test'

describe Routemaster::Controllers::Topics do
  let(:app) { described_class }

  describe 'POST /topics/:name' do
    let(:perform) { post "/topics/widgets", payload, 'CONTENT_TYPE' => 'application/json' }
    let(:payload) { %{
      { event: 'create', url: 'http://example.com/widgets/123' }
    }.strip }

    it 'responds ok' do
      perform
      expect(last_response).to be_ok
    end

  end
end
