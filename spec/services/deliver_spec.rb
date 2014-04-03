require 'spec_helper'
require 'routemaster/services/deliver'
# require 'routemaster/models/fifo'
require 'routemaster/models/queue'
require 'spec/support/persistence'
require 'webmock/rspec'


describe Routemaster::Services::Deliver do
  # let(:buffer) { Routemaster::Models::Fifo.new('buffer') }
  # let(:queue) { double 'Queue', buffer: buffer }
  let(:buffer) { queue.buffer }
  let(:queue) { Routemaster::Models::Queue.new(subscriber: 'alice') }
  let(:callback) { 'https://alice.com/widgets' }

  subject { described_class.new(queue) }

  def make_event
    @event_counter ||= 0
    @event_counter += 1
    Routemaster::Models::Event.new(
      topic: 'widgets',
      type:  'noop',
      url:   "https://example.com/widgets/#{@event_counter}")
  end

  before do
    queue.callback = callback 
  end

  describe '#run' do
    let(:perform) { subject.run }

    context 'when there are no events' do
      it 'passes' do 
        expect { perform }.not_to raise_error
      end

      it 'does not issue requests' do
        perform
        a_request(:any, //).should_not have_been_made
      end
    end

    context 'when there are a few sendable events' do
      before do
        3.times { buffer.push make_event }
        queue.timeout = 0
        stub_request(:post, callback).to_return(status: 204, body: '')
      end
      
      it 'passes' do
        expect { perform }.not_to raise_error
      end

      it 'POSTs to the callback' do
        perform
        a_request(:post, callback).should have_been_made
      end

      it 'sends valid JSON' do
        WebMock.after_request do |request, _|
          expect(request.headers['Content-Type']).to eq('application/json')
          expect { JSON.parse(request.body) }.not_to raise_error
        end
        perform
      end

      it 'delivers events in order' do
        WebMock.after_request do |request, _|
          events = JSON.parse(request.body)
          expect(events.length).to eq(3)
          expect(events.first['url']).to match(/\/1$/)
          expect(events.last['url']).to match(/\/3$/)
        end
        perform
      end

      it 'clears the buffer' do
        perform
        expect(buffer.length).to eq(0)
      end

      context 'when the callback fails' do
        before do
          stub_request(:post, callback).to_return(status: 500)
        end

        it 'does not clear the buffer' do
          perform
          expect(buffer.length).not_to eq(0)
        end
      end
    end

    context 'when there are recent events but less than the buffer size' do
      before do
        queue.timeout = 500
        queue.max_events = 100
        3.times { buffer.push make_event }
      end

      it 'does not send events' do
        perform
        a_request(:any, callback).should_not have_been_made
      end
    end

    context 'when there are many recent events' do
      before do
        queue.timeout = 500
        queue.max_events = 3
        3.times { buffer.push make_event }
        stub_request(:post, callback).to_return(status: 204, body: '')
      end

      it 'makes a request' do
        perform
        a_request(:any, callback).should have_been_made
      end
    end
  end
end

