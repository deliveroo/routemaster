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

  def ingest_events(count)
    (1..count).map {
      described_class.ingest_event(event: make_event, subscriber: subscriber)
    }.last
  end

  describe '.ingest_event' do
    let(:perform) { ingest_events(2) }

    it { expect { perform }.not_to raise_error }

    describe 'the batch' do
      subject { perform.reload }

      its(:status) { is_expected.to eq(:early) }
      its(:length) { is_expected.to eq(2) }
      its(:attempts) { is_expected.to eq(0) }
      it { is_expected.to be_current }
    end
  end

  describe '#promote' do
    let(:batch) { ingest_events(event_count) }
    let(:event_count) { 1 }
    let(:perform) { batch.promote }

    context 'when the batch is in the early set' do
      shared_examples 'promotion' do
        it { expect { perform }.not_to raise_error }

        describe 'the batch' do
          before { perform }
          subject { batch.reload }
          
          its(:status) { is_expected.to eq(:ready) }
          its(:length) { is_expected.to eq(event_count) }
          it { is_expected.not_to be_current }
        end
      end

      context 'when the batch is full' do
        let(:event_count) { 2 }
        it_behaves_like 'promotion'
      end

      context 'when the batch is late' do
        let(:timeout) { 0 }
        it_behaves_like 'promotion'
      end

      context 'when the batch is neither full nor late' do
        it { expect { perform }.not_to raise_error }

        describe 'the batch' do
          before { perform }
          subject { batch.reload }
          
          its(:status) { is_expected.to eq(:early) }
          its(:length) { is_expected.to eq(event_count) }
          it { is_expected.to be_current }
        end
      end
    end

    context 'when the batch is ready' do
      let(:event_count) { 2 }
      before { perform }

      subject { described_class.new(uid: batch.uid, status: :early) }
      it { expect { subject.promote }.to raise_error(described_class::NotEarlyError) }
    end

    context 'when the batch data has disappeared' do
      let(:event_count) { 2 }
      before { _redis.del("batch:#{batch.uid}") }

      it { expect { batch.promote }.to raise_error(described_class::NonexistentError) }
    end
  end


  describe '.auto_promote' do
    subject { described_class.auto_promote }

    context 'when no batches are stale' do
      it { is_expected.to be_nil }
    end

    context 'when there is a promotable batch' do
      before { ingest_events(3) }
      let(:timeout) { 0 }

      it { is_expected.to be_a_kind_of(described_class) }
    end
  end


  describe '.acquire' do
    let(:worker_id) { 'f000-b444' }
    let(:result) { described_class.acquire(worker_id: worker_id, timeout: 1) }

    context 'when there are no ready batches' do
      it { expect(result).to be_nil }
    end

    context 'when there is a ready batch' do
      before { ingest_events(3).promote }

      describe 'the batch' do
        subject { result.reload }

        its(:status) { is_expected.to eq(:pending) }
        its(:length) { is_expected.to eq(3) }
        its(:worker_id) { is_expected.to eq(worker_id) }
        it { is_expected.not_to be_current }
      end
    end
  end


  describe '#ack' do
    subject { ingest_events(3).promote ; described_class.acquire(worker_id: 'foobar') }
    let(:perform) { subject.ack }

    it { expect { perform }.not_to raise_error }
  
    describe 'the batch' do
      before { perform }
      it { expect { subject.length }.to raise_error(described_class::NonexistentError) }
      its(:status) { is_expected.to eq(:acked) }
      its(:worker_id) { is_expected.to be_nil }
    end
  end


  describe '#nack' do
    let(:batch) { ingest_events(3).promote ; described_class.acquire(worker_id: 'foobar') }
    let(:perform) { batch.nack }

    it { expect { perform }.not_to raise_error }

    describe 'the batch' do
      subject { batch.reload }
      before { perform }

      its(:status) { is_expected.to eq(:early) }
      its(:length) { is_expected.to eq(3) }
      its(:attempts) { is_expected.to eq(1) }
      its(:worker_id) { is_expected.to be_nil }
    end
  end

end
