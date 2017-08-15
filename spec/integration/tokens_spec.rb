require 'spec_helper'
require 'spec/support/integration'
require 'spec/support/env'
require 'routemaster/client'
require 'routemaster/models/client_token'
require 'routemaster/models/subscriber'
require 'routemaster/models/topic'
require 'routemaster/models/batch'

describe 'Client integration', slow:true do
  let(:processes) { Acceptance::ProcessLibrary.new }
  before { WebMock.disable! }

  let(:token) { 'seedkey--1c44d34f-6e53-4a4f-9756-4bb8480a7a19' }
  before { ENV['ROUTEMASTER_CLIENTS'] = token }

  let(:client_processes) {[
    processes.server_tunnel,
    processes.web,
  ]}

  before { client_processes.each { |c| c.start } }
  before { client_processes.each { |c| c.wait_start } }
  after  { client_processes.each { |c| c.wait_stop } }
  after  { client_processes.each { |c| c.stop } }

  let(:client) { 
    Routemaster::Client.configure do |c|
      c.url = 'https://127.0.0.1:17893'
      c.uuid = token
      c.verify_ssl = false
    end
  }

  after { Routemaster::Client::Connection.reset_connection }

  it 'allows tokens from ROUTEMASTER_CLIENTS' do
    expect { client }.not_to raise_error
  end
end

