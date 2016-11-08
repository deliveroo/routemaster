require 'spec_helper'
require 'spec/support/integration'
require 'routemaster/client'
require 'routemaster/models/subscription'

describe 'Event delivery', type: :acceptance do
  let(:processes) { Acceptance::ProcessLibrary.new }

  before { WebMock.disable! }

  before { processes.all.each { |p| p.start } }
  before { processes.all.each { |p| p.wait_start } }
  after  { processes.all.each { |p| p.wait_stop } }
  after  { processes.all.each { |p| p.stop } }

  let(:client) {
    Routemaster::Client.new(url: 'https://127.0.0.1:17893', delivery_token: 'demo', verify_ssl: false)
  }
  let(:max_events) { '1' }
  let(:timeout) { '0' }
  let(:receiver) { processes.client }

  def subscribe
    # FIXME: this has to be here because subscribing doesnt implicitely
    # create the topics (it should)
    client.created('cats', 'https://example.com/cats/1')
    client.created('dogs', 'https://example.com/dogs/1')

    client.subscribe(
      topics:   %w(cats dogs),
      callback: 'https://127.0.0.1:17894/events',
      uuid:     'demo-client',
      max:      Integer(max_events),
      timeout:  Integer(timeout)
    )
  end

  it 'delivers a single event' do
    subscribe
    client.created('cats', 'https://example.com/cats/1')
    processes.client.wait_log %r(received https://example.com/cats/1, create, cats)
  end

  it 'delivers events from multiple topics' do
    subscribe
    client.created('cats', 'https://example.com/cats/1')
    client.created('dogs', 'https://example.com/dogs/1')
    processes.client.wait_log %r{create, cats}
    processes.client.wait_log %r{create, dogs}
  end

  it 'delivers batches of events' do
    max_events.replace '5'
    timeout.replace '1000'
    subscribe

    5.times do |index|
      client.created('cats', "https://example.com/cats/#{index}")
    end
    processes.watch.wait_log %r{delivered 5 events}
  end

  it 'delivers partial batches after a timeout' do
    max_events.replace '10'
    timeout.replace '1000'
    subscribe

    5.times do |index|
      client.created('cats', "https://example.com/cats/#{index}")
    end
    processes.watch.wait_log %r{delivered 5 events}
  end
end
