require 'spec_helper'
require 'routemaster/application'
require 'routemaster/models/client_token'
require 'spec/support/rack_test'

describe Routemaster::Application, type: :controller do

  described_class.class_eval do
    get '/fail' do
      raise StandardError
    end
  end

  let(:app) { described_class }

  let(:perform_fail) { get '/fail' }

  describe 'unknown endpoint' do

    before do
      uuid = Routemaster::Models::ClientToken.generate_api_key({"service": "rspec", "owner": "rspec"})
      authorize uuid, 'demo'
    end

    it 'responds with an error, no content' do
      post '/whatever'
      expect(last_response).to be_not_found
      expect(last_response.body).to be_empty
    end

    it 'delivers the exception' do
      expect_any_instance_of(app).to receive(:deliver_exception)
        .with(an_instance_of(StandardError))
      perform_fail
    end

    it 'responds with a 500' do
      allow_any_instance_of(app).to receive(:deliver_exception)
      perform_fail
      expect(last_response.status).to eq(500)
    end
  end

end
