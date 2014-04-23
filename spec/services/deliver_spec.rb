require 'spec_helper'
require 'routemaster/services/deliver'
require 'routemaster/models/subscription'
require 'spec/support/persistence'
require 'spec/support/events'
require 'webmock/rspec'
require 'timecop'


describe Routemaster::Services::Deliver do
  let(:buffer) { Array.new }
  let(:subscription) { Routemaster::Models::Subscription.new(subscriber: 'alice') }
  let(:callback) { 'https://alice.com/widgets' }
  let(:callback_auth) { 'https://hello:x@alice.com/widgets' }

  subject { described_class.new(subscription, buffer) }

  before do
    subscription.uuid = 'hello'
    subscription.callback = callback
  end

  describe '#run' do
    let(:perform) { subject.run }

    context 'when there are no events' do

      it 'passes' do
        expect { perform }.not_to raise_error
      end

      it 'returns falsy' do
        expect(perform).to be_false
      end

      it 'does not issue requests' do
        perform
        a_request(:any, //).should_not have_been_made
      end
    end

    context 'when there are events' do
      before do
        Timecop.travel(-600) do
          3.times { buffer.push make_event }
        end
        subscription.timeout = 0
        stub_request(:post, callback_auth).to_return(status: 204, body: '')
      end

      it 'passes' do
        expect { perform }.not_to raise_error
      end

      it 'returns true' do
        expect(perform).to be_true
      end

      it 'POSTs to the callback' do
        perform
        a_request(:post, callback_auth).should have_been_made
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

      context 'when the callback fails' do
        before do
          stub_request(:post, callback_auth).to_return(status: 500)
        end

        it 'raises an exception' do
          expect { perform }.to raise_error(described_class::CantDeliver)
        end
      end
    end

    context 'when there are recent events but less than the buffer size' do
      before do
        subscription.timeout = 500
        subscription.max_events = 100
        3.times { buffer.push make_event }
      end

      it 'does not send events' do
        perform
        a_request(:any, callback_auth).should_not have_been_made
      end

      it 'returns flasy' do
        expect(perform).to be_false
      end
    end

    context 'when there are many recent events' do
      before do
        subscription.timeout = 500
        subscription.max_events = 3
        3.times { buffer.push make_event }
        stub_request(:post, callback_auth).to_return(status: 204, body: '')
      end

      it 'makes a request' do
        perform
        a_request(:any, callback_auth).should have_been_made
      end

      it 'returns truthy' do
        expect(perform).to be_true
      end
    end
  end
end
