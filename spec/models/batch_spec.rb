require 'spec_helper'
require 'spec/support/events'
require 'spec/support/persistence'
require 'routemaster/models/batch'
require 'routemaster/models/subscriber'

describe Routemaster::Models::Batch do
  let(:timeout) { 5000 }
  let(:batch_size) { 3 }
  let(:during_ingest) {}
  let(:subscriber) {
    Routemaster::Models::Subscriber.new(name: 'alice').tap do |s|
      s.max_events = batch_size
      s.timeout = timeout
    end
  }

  def do_ingest(count)
    @counter ||= 0
    (1..count).map { 
      described_class.ingest(
        data:       "payload#{@counter += 1}", 
        timestamp:  Routemaster.now, 
        subscriber: subscriber) { during_ingest }
    }.last
  end

  describe '.ingest' do
    let(:perform) { do_ingest(1) }
    let(:expected_batches_added)   { 1 }
    let(:expected_batches_removed) { 0 }
    let(:expected_events_added)    { 1 }
    let(:expected_events_removed)  { 0 }
    let(:expected_batch_length)    { 1 }

    shared_examples 'event adder' do
      it { expect { perform }.not_to raise_error }

      describe 'the batch' do
        subject { perform.reload }

        its(:length) { is_expected.to eq(expected_batch_length) }
        its(:attempts) { is_expected.to eq(0) }
        it { is_expected.to be_current }
      end

      describe 'counters' do
        it 'increments the batch counter' do
          expect { perform }.to change {
            described_class.counters[:batches]['alice']
          }.by(expected_batches_added - expected_batches_removed)
        end

        it 'increments the event counter' do
          expect { perform }.to change {
            described_class.counters[:events]['alice']
          }.by(expected_events_added - expected_events_removed)
        end
      end

      it 'broadcasts events_added' do
        listener = double
        Wisper.subscribe(listener) do
          expect(listener).to receive(:events_added).with(name: 'alice', count: 1).exactly(expected_events_added).times
          perform
        end
      end
    end

    context 'when there is no batch' do
      it_behaves_like 'event adder'

      context 'when a batch is concurrently created' do
        let(:expected_batches_added) { 2 }
        let(:expected_events_added)  { 2 }
        let(:expected_batch_length)  { 1 }

        let(:during_ingest) do
          described_class.ingest(
            data:       'other', 
            timestamp:  Routemaster.now, 
            subscriber: subscriber)
        end

        it 'adds to a separate batch' do
          perform
          expect(Routemaster::Models::Batch.all.count).to eq(2)
        end

        it_behaves_like 'event adder'
      end
    end

    context 'when there is a current batch' do
      let(:expected_batches_added) { 0 }
      let(:expected_batch_length) { 2 }

      let!(:batch) do
        described_class.ingest(
          data:       'other', 
          timestamp:  Routemaster.now, 
          subscriber: subscriber)
      end

      it_behaves_like 'event adder'

      context 'when the current batch is deleted in flight' do
        let(:expected_batches_removed) { 1 }
        let(:expected_batches_added)   { 1 }
        let(:expected_events_removed)  { 1 }
        let(:expected_batch_length)    { 1 }
        let(:during_ingest) { batch.delete }
        it_behaves_like 'event adder'
      end

      context 'when the current batch is promoted in flight' do
        let(:expected_batches_added) { 1 }
        let(:expected_batch_length)  { 1 }
        let(:during_ingest) { batch.promote }
        it_behaves_like 'event adder'
      end
    end

    context 'when filling the batch' do
      context 'on the first event' do
        let(:batch_size) { 1 }
        it 'gets promoted' do
          expect(do_ingest(batch_size)).not_to be_current 
        end
      end

      context 'on the second event' do
        let(:batch_size) { 2 }
        it 'gets promoted' do
          expect(do_ingest(batch_size)).not_to be_current 
        end
      end
    end
  end



  describe '#promote' do
    let(:batch) { do_ingest(2) }
    let(:perform) { batch.promote }

    it { expect { perform }.not_to raise_error }
    it { expect { perform }.to change { batch.current? }.from(true).to(false) }

    context 'when the batch has been deleted' do
      let(:batch) { do_ingest(2).promote.delete.reload }

      it { expect { perform }.not_to raise_error }
    end
  end


  describe '#delete' do
    let!(:batch) { do_ingest(2) }
    let(:perform) { batch.reload.delete }

    it { expect { perform }.not_to raise_error }

    it 'removes the batch from the index' do
      expect { perform }.to change { described_class.all.count }.from(1).to(0)
    end

    it 'removes the batch data' do
      expect { perform }.to change { batch.exists? }.from(true).to(false)
    end

    it 'makes the batch non-current' do
      expect { perform }.to change { batch.current? }.to(false)
    end

    describe 'counters' do
      it 'increments the batch counter' do
        expect { perform }.to change {
          described_class.counters[:batches]['alice']
        }.by(-1)
      end

      it 'increments the event counter' do
        expect { perform }.to change {
          described_class.counters[:events]['alice']
        }.by(-2)
      end
    end

    it 'broadcasts' do
      listener = double
      Wisper.subscribe(listener) do
        expect(listener).to receive(:events_removed).with(name: 'alice', count: 2)
        perform
      end
    end
  end


  describe '#data' do
    subject { do_ingest(2) }
    it 'returns the data' do
      expect(subject.data).to eq %w[payload1 payload2]
    end
  end


  describe '#attempts' do
    subject { do_ingest(2) }

    it { expect(subject.attempts).to eq(0) }
  end


  describe '#length' do
    subject { do_ingest(2) }
    let(:result) { subject.reload.length }

    it { expect(result).to eq(2) }

    context 'when the batch was deleted' do
      before { subject.promote.delete }

      it { expect(result).to eq(0) }
    end
  end


  describe '#valid?' do
    let(:batch) { do_ingest(3) }
    subject { batch.reload }

    it 'is false when the batch was deleted' do
      batch.delete
      expect(subject).not_to be_valid
    end

    it 'is false when the subscriber was deleted' do
      subscriber.destroy
      expect(subject).not_to be_valid
    end

    it 'is true otherwise' do
      expect(subject).to be_valid
    end
  end

  describe '#full?' do
    it 'is true when the batch is full' do
      expect(do_ingest(3)).to be_full
    end

    it 'is false when the batch is not full' do
      expect(do_ingest(2)).not_to be_full
    end
  end


  describe '#fail' do
    subject { do_ingest(2) }
    let(:perform) { subject.fail }

    it { expect { perform }.to change { subject.attempts }.from(0).to(1) }
    it { expect(perform).to eq(1) }
  end


  describe '#subscriber' do
    subject { do_ingest(2) }
    let(:result) { subject.reload.subscriber }

    it 'returns the subscriber' do
      expect(result).to eq(subscriber)
    end
    
    context 'when the subscriber has been deleted' do
      before { subscriber.destroy }

      it 'returns nil' do
        expect(result).to be_nil
      end
    end
  end


  describe 'Iterator' do
    subject { described_class.all }
    let!(:batch1) { do_ingest(2).promote }
    let!(:batch2) { do_ingest(2).promote }

    describe '.each' do
      it 'yields all batches' do
        result = []
        subject.each { |x| result << x }
        expect(result).to include(batch1)
        expect(result).to include(batch2)
      end
    end
  end

end
