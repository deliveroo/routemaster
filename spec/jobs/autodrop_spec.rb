require 'spec_helper'
require 'spec/support/persistence'
require 'spec/support/counters'
require 'routemaster/jobs/autodrop'
require 'routemaster/models/database'
require 'routemaster/models/subscriber'
require 'routemaster/models/batch'

describe Routemaster::Jobs::Autodrop do
  subject { described_class.new(batch_size: 2, database: database) }
  let(:database) { double 'database' }
  let(:too_full) {[ false ]}
  let(:empty_enough) {[ true ]}

  def do_ingest(count, name)
    subscriber = Routemaster::Models::Subscriber.new(name: name)
    1.upto(count) do |idx|
      Routemaster::Models::Batch.ingest(data: "payload#{idx}", timestamp: Routemaster.now, subscriber: subscriber)
    end
  end

  before do
    allow(database).to receive(:too_full?).and_return(*too_full)
    allow(database).to receive(:empty_enough?).and_return(*empty_enough)
  end

  context 'when there are no subscribers' do
    it 'returns falsey' do
      expect(subject.call).to be_falsey
    end
  end

  context 'with batches' do
    before do
      do_ingest(10, 'alice')
      do_ingest(5, 'bob')
      do_ingest(3, 'charlie')
    end

    context 'and the database is too full' do
      let(:too_full) {[ true ]}
      let(:empty_enough) {[ false, true ]}
      
      it 'returns the number of batches removed' do
        expect(subject.call).to eq(2)
      end
      
      it 'actually deletes batches' do
        expect { subject.call }.to change { Routemaster::Models::Batch.all.count }.by(-2)
      end

      it 'increments events.autodropped' do
        expect { subject.call }.to change { get_counter('events.autodropped', queue: 'alice') }.from(0).to(10)
      end
    end
  end
end
