require 'spec_helper'
require 'routemaster/services/deliver'
require 'routemaster/models/subscriber'
require 'spec/support/persistence'
require 'spec/support/events'
require 'spec/support/webmock'
require 'timecop'


describe Routemaster::Services::Deliver do
  let(:buffer) { Array.new }
  let(:subscriber) { Routemaster::Models::Subscriber.new(name: 'alice') }
  let(:callback) { 'https://alice.com/widgets' }

  subject { described_class.new(subscriber, buffer) }

  before do
    WebMock.enable!
    subscriber.uuid = 'hello'
    subscriber.callback = callback
  end

  after do
    WebMock.disable!
  end

  describe '#run' do
    let(:perform) { subject.run }

    context 'when there are no events' do

      it 'passes' do
        expect { perform }.not_to raise_error
      end

      it 'returns falsy' do
        expect(perform).to eq(false)
      end

      it 'does not issue requests' do
        perform
        expect(a_request(:any, //)).not_to have_been_made
      end
    end

    context 'when there are events' do
      before do
        Timecop.travel(-600) do
          3.times { buffer.push make_event }
        end
        subscriber.timeout = 0
        stub_request(:post, callback).with(basic_auth: %w[hello x]).to_return(status: 204, body: '')
      end

      it 'passes' do
        expect { perform }.not_to raise_error
      end

      it 'returns true' do
        expect(perform).to eq(true)
      end

      it 'POSTs to the callback' do
        perform
        expect(a_request(:post, callback).with(basic_auth: %w[hello x])).to have_been_made
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
          stub_request(:post, callback).with(basic_auth: %w[hello x]).to_return(status: 500)
        end

        it 'raises an exception' do
          expect { perform }.to raise_error(described_class::CantDeliver)
        end
      end

      context 'when the connection fails' do
        before do
          {
            success?:       false,
            timed_out?:     false,
            response_code:  0,
            return_message: "Couldn't resolve host name",
          }.each_pair do |k,v|
            allow_any_instance_of(Typhoeus::Response).to receive(k).and_return(v)
          end
        end

        it { expect { perform }.to raise_error(described_class::CantDeliver) }
      end
    end

    context 'when there are recent events but less than the buffer size' do
      before do
        subscriber.timeout = 500
        subscriber.max_events = 100
        3.times { buffer.push make_event }
      end

      it 'does not send events' do
        perform
        expect(a_request(:any, callback)).not_to have_been_made
      end

      it 'returns flasy' do
        expect(perform).to eq(false)
      end
    end

    context 'when there are many recent events' do
      before do
        subscriber.timeout = 500
        subscriber.max_events = 3
        3.times { buffer.push make_event }
        stub_request(:post, callback).with(basic_auth: %w[hello x]).to_return(status: 204, body: '')
      end

      it 'makes a request' do
        perform
        expect(a_request(:any, callback).with(basic_auth: %w[hello x])).to have_been_made
      end

      it 'returns truthy' do
        expect(perform).to eq(true)
      end
    end

    context 'when the delivery times out' do
      let(:port) { 12024 }
      let(:callback) { "https://127.0.0.1:12024/callback" }
      let!(:listening_thread) do
        Thread.new do
          s = TCPServer.new port
          s.accept
        end
      end

      before do
        subscriber.timeout = 500
        subscriber.max_events = 3
        3.times { buffer.push make_event }
        WebMock.disable!
      end

      after { listening_thread.join }

      it "raises a CantDeliver exception" do
        expect { perform }.to raise_error(described_class::CantDeliver)
      end
    end
  end
end
