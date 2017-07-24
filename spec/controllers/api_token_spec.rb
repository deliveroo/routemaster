require 'spec_helper'
require 'routemaster/application'
require 'routemaster/controllers/api_token'
require 'spec/support/rack_test'
require 'spec/support/persistence'

describe Routemaster::Controllers::ApiToken, type: :controller do
  let(:root_key) { ENV['ROUTEMASTER_ROOT_KEY']}
  let(:app) { described_class.new }

  describe '/api_tokens endpoint' do

    let(:list_keys) do
      basic_authorize root_key, 'x'
      get '/api_tokens'
    end

    let(:create_key) do
      basic_authorize root_key, 'x'
      post '/api_tokens',
        { 'name' => 'alice' }.to_json,
        'CONTENT_TYPE' => 'application/json'
    end

    it 'returns a 204 when no keys exist' do
      list_keys
      expect(last_response.status).to eq(204)
      expect(last_response.body).to be_empty
    end

    it 'can request a new token' do
      create_key
      response_body = JSON.parse(last_response.body)
      expect(last_response.status).to eq(201)
      expect(response_body).to have_key 'token'
      expect(response_body).to include('name' => 'alice', 'token' => anything)
    end

    it 'can list existing tokens' do
      create_key
      list_keys
      response_body = JSON.parse(last_response.body)
      expect(last_response.status).to eq(200)
      expect(response_body).to include('name' => 'alice', 'token' => anything)
    end

    it 'can delete key and have an empty list' do
      create_key
      new_key = JSON.parse(last_response.body)['token']
      basic_authorize root_key, 'x'
      delete "/api_tokens/#{new_key}"
      expect(last_response.status).to eq(204)
      expect(last_response.body).to be_empty
      list_keys
      expect(last_response.status).to eq(204)
      expect(last_response.body).to be_empty
    end
  end
end
