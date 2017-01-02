require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/events'
require 'spec/support/webmock'
require 'spec/support/wisper'
require 'timecop'
require 'routemaster/services/deliver'
require 'routemaster/models/subscriber'


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

  describe '#call' do
    let(:perform) { subject.call }
    let(:callback_status) { 204 }

    before do
      @stub = stub_request(:post, callback).
        with(basic_auth: %w[hello x]).
        with { |req| @request = req }.
        to_return(status: callback_status, body: '')
    end

    shared_examples 'a broadcaster' do |event, count|
      it 'broadcasts' do
        expect { perform rescue nil }.to broadcast(event, name: 'alice', count: count)
      end
    end

    context 'when there are no events' do
      it 'passes' do
        expect { perform }.not_to raise_error
      end

      it 'POSTs to the callback' do
        perform
        expect(@stub).to have_been_requested
      end

      it_behaves_like 'a broadcaster', :delivery_succeeded, 0
    end

    context 'when there are events' do
      before do
        3.times { buffer.push make_event }
      end

      it 'passes' do
        expect { perform }.not_to raise_error
      end

      it 'returns true' do
        expect(perform).to eq(true)
      end

      it 'POSTs to the callback' do
        perform
        expect(@stub).to have_been_requested
      end

      it 'sends valid JSON' do
        perform
        expect(@request.headers['Content-Type']).to eq('application/json')
        expect { JSON.parse(@request.body) }.not_to raise_error 
      end

      it 'delivers events in order' do
        perform
        events = JSON.parse(@request.body)
        expect(events.length).to eq(3)
        expect(events.first['url']).to match(/\/1$/)
        expect(events.last['url']).to match(/\/3$/)
      end

      it_behaves_like 'a broadcaster', :delivery_succeeded, 3

      shared_examples 'failure' do
        it "raises a CantDeliver exception" do
          expect { perform }.to raise_error(described_class::CantDeliver)
        end

        it_behaves_like 'a broadcaster', :delivery_failed, 3
      end

      context 'when the callback 500s' do
        let(:callback_status) { 500 }

        it_behaves_like 'failure'
      end

      context 'when the callback cannot be resolved' do
        let(:callback) { "https://nonexistent.example.com/callback" }
        before { WebMock.disable! }

        it_behaves_like 'failure'
      end

      context 'with fake local server' do
        let(:port) { 12024 }
        let(:callback) { "https://127.0.0.1:#{port}/callback" }

        before { WebMock.disable! }

        context 'when delivery times out' do
          let!(:listening_thread) do
            Thread.new do
              s = TCPServer.new port
              s.accept
              s.close
            end
          end

          after { listening_thread.join }

          it_behaves_like 'failure'
        end

        context 'when connection fails' do
          # no server thread started here
          it_behaves_like 'failure'
        end
      end
    end

  end
end
