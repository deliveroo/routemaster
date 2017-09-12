require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/events'
require 'spec/support/webmock'
require 'spec/support/counters'
require 'routemaster/services/deliver'
require 'routemaster/models/subscriber'
require 'routemaster/models/batch'
require 'routemaster/services/codec'

describe Routemaster::Services::Deliver do
  let(:buffer) { Array.new }
  let(:last_attempt_at) { Routemaster.now - 200_000 }
  let(:base_hp) { 50 }
  let(:subscriber) do
    Routemaster::Models::Subscriber.new(
      name: 'alice',
      attributes: {
        'last_attempted_at' => last_attempt_at,
        'health_points' => base_hp.to_s
      }
    ).save
  end

  let(:batch) do
    buffer.map { |event|
      Routemaster::Models::Batch.ingest(
        subscriber: subscriber,
        timestamp:  event.timestamp,
        data:       Routemaster::Services::Codec.new.dump(event))
    }.last
  end

  def reloaded_subscriber
    Routemaster::Models::Subscriber.new(name: subscriber.name)
  end

  let(:callback) { 'https://alice.com/widgets' }

  subject { described_class.new(batch: batch, events: buffer) }

  before do
    WebMock.enable!
    subscriber.uuid = 'hello'
    subscriber.callback = callback
    subscriber.save
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

    shared_examples 'an event counter' do |options|
      count = options.fetch(:count)
      tag = { status: options.fetch(:status) }

      it 'increments delivery.events counter' do
        expect { perform rescue nil }.to change { 
          get_counter('delivery.events', tag.merge(queue: 'alice'))
        }.by(count)
      end

      it 'increments delivery.batches counter' do
        expect { perform rescue nil }.to change { 
          get_counter('delivery.batches', tag.merge(queue: 'alice'))
        }.by(1)
      end

      context 'on the first delivery attempt' do
        before { batch.load_and_count }

        # double check preconditions
        it { perform rescue nil ; expect(batch.attempts).to eq 1 }

        it 'increments latency.batches.count counter' do
          expect { perform rescue nil }.to change {
            get_counter('latency.batches.count', { queue: 'alice' })
          }.by(1)
        end

        it 'increments latency.batches.first_attempt counter' do
          expect { perform rescue nil }.to change {
            get_counter('latency.batches.first_attempt', { queue: 'alice' })
          }
        end

        if options[:status] == 'success'
          it 'increments latency.batches.last_attempt counter' do
            expect { perform rescue nil }.to change {
              get_counter('latency.batches.last_attempt', { queue: 'alice' })
            }
          end
        else
          it 'does not change latency.batches.last_attempt counter' do
            expect { perform rescue nil }.not_to change {
              get_counter('latency.batches.last_attempt', { queue: 'alice' })
            }
          end
        end
      end

      context 'on the second delivery attempt' do
        before { 2.times { batch.reload.load_and_count} }

        # double check preconditions
        it { perform rescue nil ; expect(batch.attempts).to eq 2 }

        it 'does not change latency.batches.count counter' do
          expect { perform rescue nil }.not_to change {
            get_counter('latency.batches.count', { queue: 'alice' })
          }
        end

        it 'does not increment latency.batches.first_attempt counter' do
          expect { perform rescue nil }.not_to change {
            get_counter('latency.batches.first_attempt', { queue: 'alice' })
          }
        end
      end

      unless options[:no_timer]
        it 'increments delivery.time counter' do
          expect { perform rescue nil }.to change {
            get_counter('delivery.time', tag.merge(queue: 'alice'))
          }
        end

        it 'increments delivery.time counter' do
          expect { perform rescue nil }.to change {
            get_counter('delivery.time2', tag.merge(queue: 'alice'))
          }
        end
      end
    end

    shared_examples 'a delivery failure' do |options|
      options ||= {}
 
      it "raises a Routemaster::Exceptions::DeliveryFailure exception" do
        expect { perform }.to raise_error(Routemaster::Exceptions::DeliveryFailure)
      end

      it_behaves_like 'an event counter', options.merge(count: 3, status: 'failure')
      it_behaves_like 'it updates the HP of the subscriber', by: -2
    end

    shared_examples 'it updates the HP of the subscriber' do |options|
      by = options.fetch(:by)
      description = (by >= 0) ? 'increases' : 'decreases'

      it "#{description} the health points of the subscriber by #{by}" do
        expect { perform rescue nil }.to change {
          reloaded_subscriber.health_points
        }.from(base_hp).to(base_hp + by)
      end
    end

    shared_examples_for 'a subscriber throttler' do
      let(:throttle) do
        instance_double(Routemaster::Services::Throttle, notice_success: base_hp, notice_failure: base_hp)
      end
      let(:throttle_klass) { double("ThrottleKlass") }

      before do
        allow(throttle_klass).to receive(:new).with(subscriber).and_return(throttle)
      end

      subject { described_class.new(batch: batch, events: buffer, throttle_service: throttle_klass) }

      context 'when the throttler says that it is OK to deliver to the subscriber' do
        before do
          expect(throttle).to receive(:check!).and_return(true)
        end

        it "doesn't abort the delivery" do
          expect { perform }.to_not raise_error
        end

        it 'increments delivery.batches counter, reporting the batch as successful' do
          expect { perform rescue nil }.to change { 
            get_counter('delivery.batches', {queue: 'alice', status: "success"})
          }.by(1)
        end
      end

      context 'when the throttler says that deliveries to the subscriber should be delayed' do
        before do
          expect(throttle).to receive(:check!) do
            raise Routemaster::Exceptions::EarlyThrottle.new(10.0, subscriber.name)
          end
        end

        it "raises a Routemaster::Exceptions::DeliveryFailure exception" do
          expect { perform }.to raise_error(Routemaster::Exceptions::DeliveryFailure)
        end


        it "does NOT change the health points of the subscriber" do
          expect { perform rescue nil }.to_not change {
            reloaded_subscriber.health_points
          }
        end

        it 'increments delivery.batches counter, reporting the batch as throttled' do
          expect { perform rescue nil }.to change { 
            get_counter('delivery.batches', {queue: 'alice', status: "throttled"})
          }.by(1)
        end
      end
    end


    context 'when there are no events' do
      before {
        buffer << make_event
        batch
        buffer.clear
      }

      it 'passes' do
        expect { perform }.not_to raise_error
      end

      it 'POSTs to the callback' do
        perform
        expect(@stub).to have_been_requested
      end

      it_behaves_like 'an event counter', count: 0, status: 'success'
      it_behaves_like 'it updates the HP of the subscriber', by: 1
      it_behaves_like 'a subscriber throttler'
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

      describe 'data payload' do
        it 'adds :data if a payload is present' do
          buffer.push Routemaster::Models::Event.new(
            topic: 'things',
            type:  'noop',
            url:   "https://example.com/things/1",
            data:  { foo: 'bar' })
          perform
          events = JSON.parse(@request.body)
          expect(events.last['data']).to eq('foo' => 'bar')
        end

        it 'does not add :data when the payload is absent' do
          perform
          events = JSON.parse(@request.body)
          expect(events.last).not_to have_key('data')
        end
      end

      it_behaves_like 'an event counter', count: 3, status: 'success'
      it_behaves_like 'it updates the HP of the subscriber', by: 1
      it_behaves_like 'a subscriber throttler'

      context 'when the callback 500s' do
        let(:callback_status) { 500 }

        it_behaves_like 'a delivery failure'
      end

      context 'when the callback cannot be resolved' do
        let(:callback) { "https://nonexistent.example.com/callback" }
        before { WebMock.disable! }

        it_behaves_like 'a delivery failure'
      end

      context 'with fake local server', slow: true do
        let(:port) { 1024 + rand(30_000) }
        let(:callback) { "https://127.0.0.1:#{port}/callback" }

        before { WebMock.disable! }

        context 'when delivery times out' do
          let(:q) { Queue.new }
          let(:listening_thread) do
            Thread.new do
              Thread.current.abort_on_exception = true
              s = TCPServer.new port
              q.push :started
              s.accept
              q.pop
              s.close
            end
          end

          before do
            listening_thread
            q.pop # wait for server to start
          end

          after do
            q.push :done
            listening_thread.join # wait for server to complete
          end

          it_behaves_like 'a delivery failure'
        end

        context 'when connection fails' do
          # no server thread started here
          it_behaves_like 'a delivery failure', no_timer: true
        end
      end
    end

  end
end
