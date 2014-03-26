require 'spec_helper'
require 'routemaster/controllers/pulse'
require 'spec/support/rack_test'

describe Routemaster::Controllers::Pulse do
  let(:app) { described_class }

  let(:perform) { get '/pulse' }

  context 'when all is fine' do
    it 'succeeds' do
      perform
      expect(last_response).to be_ok
    end

    it 'does not return anything' do
      perform
      expect(last_response.body).to be_empty
    end
  end

  context 'when Redis is down' do
    xit 'returns 500'
  end
end
