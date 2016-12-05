require 'spec_helper'
require 'spec/support/env'
require 'routemaster/middleware/authentication'
require 'spec/support/rack_test'

describe Routemaster::Middleware::Authentication, type: :controller do
  class Demo
    def call(env)
      [200, {}, env.fetch('REMOTE_USER', '')]
    end
  end

  let(:app) { described_class.new(Demo.new) }
  let(:options) { Hash.new }
  let(:perform) { get '/whatever', options }

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

  context 'with proper credentials' do
    before { authorize 'john-mcfoo', 'secret' }

    shared_examples 'checks' do
      it 'succeeds' do
        perform
        expect(last_response).to be_ok
      end

      it 'returns the username' do
        perform
        expect(last_response.body).to eq('john-mcfoo')
      end
    end

    context 'using ROUTEMASTER_CLIENTS' do
      before { ENV['ROUTEMASTER_CLIENTS'] = 'bob,john-mcfoo' }
      include_examples 'checks' 
    end

    context 'using ROUTEMASTER_CLIENT_TOKENS' do
      before { ENV['ROUTEMASTER_CLIENT_TOKENS'] = 'bob,john-mcfoo' }
      include_examples 'checks' 
    end
  end
end
