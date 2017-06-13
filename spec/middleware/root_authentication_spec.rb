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

  let(:app) { described_class.new(Demo.new, /^\/protected_path.*/) }
  let(:perform) { get '/protected_path' }

  context 'without proper credentials' do
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
    let(:uuid) { Routemaster::Models::ClientToken.generate_api_key "arbitary" => "data" }
    before { authorize uuid, 'john-mcfoo' }

    it 'fails' do
      perform
      expect(last_response.status).to eq(401)
    end
  end

  context 'with $ROUTEMASTER_ROOT_KEY' do
    let(:uuid) { ENV['ROUTEMASTER_ROOT_KEY'] }
    before { authorize uuid, 'john-mcfoo' }
    it 'passes' do
      perform
      expect(last_response.status).to be(200)
    end
  end

  context 'only protects given path' do
    it 'passes' do
      get '/non_protected_path_no_auth'
      expect(last_response.status).to be(200)
    end
  end
end
