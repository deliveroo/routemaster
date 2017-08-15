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

  let(:token) { Routemaster::Models::ClientToken.create!(name: 'test') }

  after { Routemaster::Client::Connection.reset_connection }

  let(:subscriber) { Routemaster::Models::Subscriber.find(token) }
  let(:topic) { Routemaster::Models::Topic.find('widgets') }

  it 'connects' do
    expect { client }.not_to raise_error
  end

  it 'subscribes' do
    # implicitly create the topic first
    client.created('widgets', 'https://example.com/widgets/1')

    client.subscribe(
      topics: %w(widgets),
      callback: 'https://127.0.0.1:17894/events'
    )

    expect(subscriber).not_to be_nil
    expect(subscriber.callback).to eq('https://127.0.0.1:17894/events')
  end

  it 'publishes' do
    client.created('widgets', 'https://example.com/widgets/1')

    expect(topic).not_to be_nil
    expect(topic.get_count).to eq(1)
  end

  context 'with a subscriber' do
    before do
      # implicitly create the topic first
      client.created('widgets', 'https://example.com/widgets/1')

      client.subscribe(
        topics: %w(widgets),
        callback: 'https://127.0.0.1:17894/events'
      )
    end

    it 'unsubscribes from a topic' do
      client.unsubscribe('widgets')
      expect(subscriber.topics.map(&:name)).not_to include('widgets')
    end
    
    it 'unsubscribes entirely' do
      client.unsubscribe_all
      expect(subscriber).to be_nil
    end

    it 'enqueues' do
      expect {
        client.created('widgets', 'https://example.com/widgets/1')
      }.to change {
        Routemaster::Models::Batch.all.count
      }.by(1)
    end
  end

  context 'with a topic' do
    before do
      client.created('widgets', 'https://example.com/widgets/1')
    end

    it 'deletes the topic' do
      client.delete_topic('widgets')
      expect(topic).to be_nil
    end
  end
end

