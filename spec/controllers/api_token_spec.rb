require 'spec_helper'
require 'routemaster/application'
require 'routemaster/controllers/api_token'
require 'spec/support/rack_test'
require 'spec/support/persistence'

describe Routemaster::Controllers::ApiToken, type: :controller do
  let(:root_key) { ENV['ROUTEMASTER_ROOT_KEY']}
  let(:app) { described_class.new }

  def list_keys
    basic_authorize root_key, 'x'
    get '/api_tokens'
  end

  def create_key
    basic_authorize root_key, 'x'
    post '/api_tokens',
      { 'name' => 'alice' }.to_json,
      'CONTENT_TYPE' => 'application/json'
  end

  describe '/api_tokens endpoint' do
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
  end

  describe 'DELETE /api_tokens/:token' do
    def response
      basic_authorize root_key, 'x'
      delete "/api_tokens/#{token}"
      last_response
    end

    context 'when key does not exist' do
      let(:token) { 'foobar' }

      it { expect(response.status).to eq 204 }
    end

    context 'when key exists' do
      let!(:token) {
        create_key
        JSON.parse(last_response.body)['token']
      }

      it { expect(response.status).to eq 204 }

      it 'removes the key from the list' do
        expect {
          response
        }.to change {
          list_keys ; last_response.body
        }.to('')
      end

      context 'when subscriber exists' do
        before { Routemaster::Models::Subscriber.new(name: token).save }

        it 'deletes the subscriber' do
          expect { response }.to change {
            Routemaster::Models::Subscriber.find(token)&.name
          }.to(nil)
        end
      end
    end
  end
end
