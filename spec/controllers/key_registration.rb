require 'spec_helper'
require 'routemaster/application'
require 'routemaster/controllers/key_registration'
require 'routemaster/mixins/redis'
require 'spec/support/rack_test'
require 'spec/support/persistence'

describe Routemaster::Controllers::KeyRegistration, type: :controller do
  let(:root_key) {ENV["ROUTEMASTER_ROOT_KEY"]}
  let(:app) { described_class.new }

  describe '/api_keys endpoint' do

    let(:list_keys) do
      basic_authorize root_key, 'x'
      get '/api_keys'
    end

    let(:create_key) do
      basic_authorize root_key, 'x'
      post '/api_keys',
        {'service_name' => 'table_service'}.to_json,
        {'CONTENT_TYPE' => 'application/json'}
    end

    let(:delete_key) do
      basic_authorize root_key, 'x'
      delete '/api_keys',
        {'service_name' => 'table_service'}.to_json,
        {'CONTENT_TYPE' => 'application/json'}
    end

    it 'returns a 204 when no keys exist' do
      list_keys
      expect(last_response.status).to eq(204)
      expect(last_response.body).to be_empty
    end

    it 'can request and list a new uuid' do
      create_key
      response = JSON.parse(last_response.body)
      expect(last_response.status).to eq(201)
      expect(response).to have_key "new_key"

      list_keys
      expect(last_response.status).to eq(200)
      expect(JSON.parse(last_response.body)).to have_key response["new_key"]
    end

    it 'can delete key and have an empty list' do
      create_key
      new_key = JSON.parse(last_response.body)["new_key"]
      basic_authorize root_key, 'x'
      delete "/api_keys/#{new_key}", {'CONTENT_TYPE' => 'application/json'}
      expect(last_response.status).to eq(204)
      expect(last_response.body).to be_empty
      list_keys
      expect(last_response.status).to eq(204)
      expect(last_response.body).to be_empty
    end
  end
end
