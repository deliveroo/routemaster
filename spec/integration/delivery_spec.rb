require 'spec_helper'
require 'spec/support/integration'
require 'routemaster/client'
require 'routemaster/mixins/redis'
require 'routemaster/models/client_token'
require 'routemaster/models/subscription'


describe 'Event delivery', type: :acceptance, slow: true do
  let(:processes) { Acceptance::ProcessLibrary.new }

  before { WebMock.disable! }

  before { processes.all.each { |p| p.start } }
  before { processes.all.each { |p| p.wait_start } }
  after  { processes.all.each { |p| p.wait_stop } }
  after  { processes.all.each { |p| p.stop } }

  let(:uuid) do
    # Arbitrary hardcoded key
    _redis.hset('api_keys', '1c44d34f-6e53-4a4f-9756-4bb8480a7a19', 'xkey')
    '1c44d34f-6e53-4a4f-9756-4bb8480a7a19'
  end

  let(:client) {
    Routemaster::Client.configure do |c|
      c.url = 'https://127.0.0.1:17893'
      c.uuid = uuid
      c.verify_ssl = false
    end
  }
  after { Routemaster::Client::Connection.reset_connection }
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
      uuid:     uuid,
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
    processes.client.wait_log %r{received batch of 5 events}
  end

  it 'delivers data payloads' do
    subscribe
    client.created('cats', 'https://example.com/cats/42', data: { 'name' => 'garfield' })

    processes.client.wait_log /^payload: {"name":"garfield"}/
  end

  it 'delivers partial batches after a timeout' do
    max_events.replace '10'
    timeout.replace '1000'
    subscribe

    5.times do |index|
      client.created('cats', "https://example.com/cats/#{index}")
    end

    processes.client.wait_log %r{received batch of 5 events}
  end

  it 'emits ingestion metrics' do
    client.created('cats', 'https://example.com/cats/1')
    client.created('cats', 'https://example.com/cats/2')
    client.created('cats', 'https://example.com/cats/3')
    processes.watch.wait_log %r(counter:events.published:3.*topic:cats)
  end

  it 'emits queueing metrics' do
    subscribe
    client.created('cats', 'https://example.com/cats/2')
    client.created('cats', 'https://example.com/cats/3')
    processes.watch.wait_log %r(counter:events.added:2.*queue:#{uuid})
  end

  it 'emits delivery metrics' do
    subscribe
    client.created('cats', 'https://example.com/cats/2')
    client.created('cats', 'https://example.com/cats/3')
    processes.watch.wait_log %r(counter:delivery.events:2.*queue:#{uuid})
  end
end

