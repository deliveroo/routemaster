require 'spec_helper'
require 'routemaster/services/autodrop'
require 'routemaster/models/database'
require 'routemaster/models/subscriber'
require 'spec/support/persistence'

describe Routemaster::Services::Autodrop do
  let(:database) { Routemaster::Models::Database.instance }
  let(:too_full) {[ false ]}
  let(:empty_enough) {[ true ]}

  let(:subs) do
    [0,1,2].map { |n|
      Routemaster::Models::Subscriber.new(name: "sub#{n}")
    }
  end

  before do
    allow(database).to receive(:too_full?).and_return(*too_full)
    allow(database).to receive(:empty_enough?).and_return(*empty_enough)
  end

  context 'when there are no subscribers' do
    it 'returns false' do
      expect(subject.call).to be_falsey
    end
  end

  context 'with subscribers' do
    before { subs }

    context 'and the database is too full' do
      let(:too_full) {[ true ]}
      let(:empty_enough) {[ false, true ]}
      
      it 'returns 0' do
        expect(subject.call).to eq(0)
      end
    end

    context 'and messages' do
      def msg_at(timestamp)
        Routemaster::Models::Message::Ping.new(data: SecureRandom.uuid, timestamp: timestamp)
      end

      before do
        Routemaster::Models::Queue.push [subs[0]], msg_at(100)
        Routemaster::Models::Queue.push [subs[1]], msg_at(200)
        Routemaster::Models::Queue.push [subs[2]], msg_at(300)
      end

      let(:too_full) {[ true ]}
      let(:empty_enough) {[ false, false, true ]}

      it 'removes messages' do
        expect { subject.call }.to change {
          subs.map(&:queue).map(&:length)
        }.from([1,1,1]).to([0,0,1])
      end

      it 'returns the number of messages removed' do
        expect(subject.call).to eq(2)
      end
    end
  end
end
