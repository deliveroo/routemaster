require 'spec_helper'
require 'routemaster/controllers/auth'
require 'routemaster/models/client_token'
require 'spec/support/rack_test'
require 'spec/support/persistence'

describe Routemaster::Controllers::Auth, type: :controller do
  class FakeApp < Sinatra::Base
    register Routemaster::Controllers::Auth
  end

  let(:app) { Class.new(FakeApp) }
  let(:client_token) { Routemaster::Models::ClientToken.create! name: 'test' }
  let(:root_token) { ENV.fetch('ROUTEMASTER_ROOT_KEY') }

  def expect_ok
    get '/'
    expect(last_response.status).to eq(200)
  end

  def expect_forbidden
    get '/'
    expect(last_response.status).to eq(401)
  end

  def expect_body(str)
    get '/'
    expect(last_response.body).to eq(str)
  end

  def use_valid_client_token
    authorize client_token, 'test'
  end

  def use_valid_root_token
    authorize root_token, 'root'
  end

  def use_invalid_client_token
    authorize 'secret', 'joe-blackhat'
  end


  before do
    app.get '/', auth: auth_types do
      body current_token.to_s
      halt 200
    end
  end

  describe 'auth: none' do
    let(:auth_types) { :none }

    it 'passes with no auth' do
      expect_ok
    end

    it 'fails with any token' do
      use_valid_root_token
      expect_forbidden
    end
  end

  describe 'auth: client' do
    let(:auth_types) { :client }

    it 'fails with no auth' do
      expect_forbidden
    end

    it 'fails with root token' do
      use_valid_root_token
      expect_forbidden
    end

    it 'fails with invalid client token' do
      use_invalid_client_token
      expect_forbidden
    end

    it 'passes with client token' do
      use_valid_client_token
      expect_ok
    end

    it 'sets the current_token' do
      use_valid_client_token
      expect_body client_token
    end
  end

  describe 'auth: root' do
    let(:auth_types) { :root }

    it 'fails with no auth' do
      expect_forbidden
    end

    it 'passes with root token' do
      use_valid_root_token
      expect_ok
    end

    it 'fails with invalid client token' do
      use_invalid_client_token
      expect_forbidden
    end

    it 'fails with client token' do
      use_valid_client_token
      expect_forbidden
    end

    it 'sets the current_token' do
      use_valid_root_token
      expect_body root_token
    end
  end

  describe 'auth: root, client' do
    let(:auth_types) { %i[client root] }

    it 'fails with no auth' do
      expect_forbidden
    end

    it 'passes with root token' do
      use_valid_root_token
      expect_ok
    end

    it 'fails with invalid client token' do
      use_invalid_client_token
      expect_forbidden
    end

    it 'passes with client token' do
      use_valid_client_token
      expect_ok
    end
  end
end

