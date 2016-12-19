require 'spec_helper'
require 'spec/support/events'
require 'spec/support/persistence'
require 'routemaster/models/batch'
require 'routemaster/models/subscriber'

describe Routemaster::Models::Batch do
  let(:timeout) { 5000 }
  let(:subscriber) {
    Routemaster::Models::Subscriber.new(name: 'alice').tap do |s|
      s.max_events = 2
      s.timeout = timeout
    end
  }

  def do_ingest(count)
    (1..count).map { |idx|
      described_class.ingest(data: "payload#{idx}", timestamp: Routemaster.now, subscriber: subscriber)
    }.last
  end

  describe '.ingest' do
    let(:perform) { do_ingest(2) }

    it { expect { perform }.not_to raise_error }

    describe 'the batch' do
      subject { perform.reload }

      its(:length) { is_expected.to eq(2) }
      its(:attempts) { is_expected.to eq(0) }
      it { is_expected.to be_current }
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
    let(:batch) { do_ingest(3) }
    let(:perform) { batch.reload.delete  }

    context 'with a current batch' do
      it { expect { perform }.to raise_error(ArgumentError) }
    end

    context 'with a non-current batch' do
      before { batch.promote }
      
      it { expect { perform }.not_to raise_error }

      it 'removes the batch from the index' do
        expect { perform }.to change { described_class.all.count }.from(1).to(0)
      end

      it 'removes the batch data' do
        expect { perform }.to change { batch.exists? }.from(true).to(false)
      end

      describe 'the batch' do
        before { perform }
        it { expect { batch.reload.length }.to raise_error(described_class::NonexistentError) }
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


  describe '#full?' do
    it 'is true when the batch is full' do
      expect(do_ingest(2)).to be_full
    end

    it 'is false when the batch is not full' do
      expect(do_ingest(1)).not_to be_full
    end
  end


  describe '#fail' do
    subject { do_ingest(2) }
    let(:perform) { subject.fail }

    it { expect { perform }.to change { subject.attempts }.from(0).to(1) }
    it { expect(perform).to eq(1) }
  end


  describe 'Iterator' do
    subject { described_class.all }
    let!(:batch1) { do_ingest(2).promote }
    let!(:batch2) { do_ingest(2).promote }

    describe '.each' do
      it 'yields all batches' do
        result = []
        subject.each { |x| result << x }
        expect(result).to eq([batch1, batch2])
      end
    end
  end

end
