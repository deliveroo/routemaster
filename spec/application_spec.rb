require 'spec_helper'
require 'routemaster/application'
require 'routemaster/models/client_token'
require 'spec/support/rack_test'
require 'spec/support/persistence'

describe Routemaster::Application, type: :controller do

  described_class.class_eval do
    get '/fail' do
      raise StandardError
    end
  end

  let(:app) { described_class }

  let(:perform_fail) { get '/fail' }

  def authorize!
    token = Routemaster::Models::ClientToken.create!(name: 'rspec')
    authorize token, 'rspec'
  end

  describe 'default authentication' do
    it 'requires auth' do
      post '/private'
      expect(last_response.status).to eq(401)
    end

    it 'handles bad credentials' do
      authorize 'bad', 'secret'
      post '/private'
      expect(last_response.status).to eq(401)
    end
  end

  describe 'unknown endpoint' do
    before { authorize! }

    it 'responds with an error, no content' do
      post '/whatever'
      expect(last_response.status).to eq(404)
      expect(last_response.body).to be_empty
    end
  end

  describe 'exception handling' do
    before { authorize! }

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
