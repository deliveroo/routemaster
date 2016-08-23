require 'spec_helper'
require 'routemaster/controllers/health'
require 'spec/support/rack_test'
require 'json'

describe Routemaster::Controllers::Health, type: :controller do
  let(:app) { described_class }
  let(:perform) { get '/health/ping' }

  it 'succeeds, responding with pong' do
    perform
    expect(last_response.status).to eq(200)
    expect(last_response.body).to match(/pong/)
  end
end
