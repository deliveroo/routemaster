require 'spec_helper'
require 'spec/support/integration'
require 'routemaster/client'
require 'routemaster/models/subscriber'
require 'routemaster/models/topic'

describe 'Client integration' do
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

  let(:client) { Routemaster::Client.new(url: 'https://127.0.0.1:17893', uuid: 'demo', verify_ssl: false) }
  let(:subscriber) { Routemaster::Models::Subscriber.find('demo') }
  let(:topic) { Routemaster::Models::Topic.find('widgets') }
  let(:queue) { subscriber.queue }

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
      client.created('widgets', 'https://example.com/widgets/1')
      expect(queue.pop.url).to eq('https://example.com/widgets/1')
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

