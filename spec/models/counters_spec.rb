require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/counters'

describe Routemaster::Models::Counters do
  subject { described_class.instance }

  after { subject.finalize }

  describe '#incr' do
    it 'passes' do
      expect { subject.incr(:foo) }.not_to raise_error
    end

    it 'allows tags' do
      expect { subject.incr(:foo, bar: 2) }.not_to raise_error
    end
  end

  describe '#flush' do
    it 'passes without data' do
      subject.flush
    end

    it 'passes with data' do
      subject.incr :foo, bar: 1
      subject.incr :foo, bar: 2
      subject.flush
    end

    context 'on overflow' do
      before { subject.incr(:foo, count: 2**63 - 1).flush }
      let(:perform) { subject.incr(:foo).flush }

      it { expect { perform }.not_to raise_error }
      it { expect { perform }.to change { subject.dump[['foo', {}]] }.to(1) }
    end
  end

  describe '#dump' do
    before do
      subject.incr :foo, bar: 1
      subject.incr :foo, bar: 1
      subject.flush
      subject.incr :foo, bar: 2
      subject.flush
    end

    it 'returns tagged counters' do
      expect(subject.dump).to eq(
        ['foo', bar: 1] => 2,
        ['foo', bar: 2] => 1,
      )
    end
  end

  describe '#finalize' do
    before do
      subject.incr :foo, bar: 1
    end

    it 'flushes' do
      subject.finalize
      expect(subject.dump).not_to be_empty
    end
  end
end

