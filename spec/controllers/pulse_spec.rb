require 'spec_helper'
require 'routemaster/controllers/pulse'
require 'spec/support/rack_test'

describe Routemaster::Controllers::Pulse do
  let(:app) { described_class }

  let(:perform) { get '/pulse' }

  context 'when all is fine' do

    before do
      allow(described_class).to receive(:_bunny_alive?).and_return(true)
    end
    
    it 'succeeds' do
      perform
      expect(last_response.status).to eq(204)
    end

    it 'does not return anything' do
      perform
      expect(last_response.body).to be_empty
    end
  end

  context 'when the pulse serivce fails' do
    before { allow_any_instance_of(Routemaster::Services::Pulse).to receive(:run).and_return(false) }

    it 'returns 500' do
      perform
      expect(last_response).to be_server_error
    end
  end
end
