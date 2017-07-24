require 'spec_helper'
require 'spec/support/env'
require 'routemaster/middleware/root_authentication'
require 'routemaster/models/client_token'
require 'spec/support/rack_test'

describe Routemaster::Middleware::RootAuthentication, type: :controller do
  class Demo
    def call(env)
      [200, {}, env.fetch('REMOTE_USER', '')]
    end
  end

  let(:app) { described_class.new(Demo.new) }
  let(:perform) { get '/protected_path' }

  context 'without any credentials' do
    it 'fails' do
      perform
      expect(last_response.status).to eq(401)
    end
  end

  context 'with unknown credentials' do
    before { authorize 'john-mcfoo', 'secret' }

    it 'fails' do
      perform
      expect(last_response.status).to eq(401)
    end
  end

  context 'with client-token credentials' do
    let(:token) { Routemaster::Models::ClientToken.create! name: 'john-mcfoo' }
    before { authorize token, 'john-mcfoo' }

    it 'fails' do
      perform
      expect(last_response.status).to eq(401)
    end
  end

  context 'with ROUTEMASTER_ROOT_KEY' do
    let(:token) { 'dead-0000-beef' }
    before do
      ENV['ROUTEMASTER_ROOT_KEY'] = token
      authorize token, 'john-mcfoo' 
    end

    it 'passes' do
      perform
      expect(last_response.status).to be(200)
    end
  end
end
