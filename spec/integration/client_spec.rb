require 'spec_helper'
require 'spec/support/integration'
require 'routemaster/client'
require 'routemaster/models/subscription'
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

  let(:client) { Routemaster::Client.new(url: 'https://127.0.0.1:17893', uuid: 'demo') }
  let(:subscription) { Routemaster::Models::Subscription.find('demo') }
  let(:topic) { Routemaster::Models::Topic.find('widgets') }
  let(:queue) { subscription.queue }

  it 'connects' do
    expect { client }.not_to raise_error
  end

  it 'subscribes' do
    client.subscribe(
      topics: %w(widgets),
      callback: 'https://127.0.0.1:17894/events'
    )

    expect(subscription).not_to be_nil
    expect(subscription.callback).to eq('https://127.0.0.1:17894/events')
  end
  
  it 'publishes' do
    client.created('widgets', 'https://example.com/widgets/1')

    expect(topic).not_to be_nil
    expect(topic.get_count).to eq(1)
  end

  it 'enqueues' do
    client.subscribe(
      topics: %w(widgets),
      callback: 'https://127.0.0.1:17894/events'
    )
    client.created('widgets', 'https://example.com/widgets/1')

    expect(queue.pop.url).to eq('https://example.com/widgets/1')
  end
end

