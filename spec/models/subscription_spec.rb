require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/topic'
require 'routemaster/models/subscriber'
require 'routemaster/models/subscription'

describe Routemaster::Models::Subscription do
  let(:topic) { Routemaster::Models::Topic.new(name: 'widget', publisher: 'charlie') }
  let(:subscriber_a) { Routemaster::Models::Subscriber.new(name: 'alice') }
  let(:subscriber_b) { Routemaster::Models::Subscriber.new(name: 'bob') }

  let(:record_a) { described_class.new(topic: topic, subscriber: subscriber_a) }
  let(:record_b) { described_class.new(topic: topic, subscriber: subscriber_b) }

  subject { record_a }

  describe '#save' do
    it { expect { subject.save }.not_to raise_error }

    it 'has side effects' do
      subject
      expect { subject.save }.to change { _redis.keys.sort }
    end
  end

  describe '#destroy' do
    it 'passes at rest' do
      expect { subject.destroy }.not_to raise_error
    end

    it 'passes when saved' do
      expect { subject.save.destroy }.not_to raise_error
    end

    it 'is idempotent' do
      subject.save.destroy
      expect { subject.destroy }.not_to change { _redis.keys.sort }
    end

    it 'cleans up' do
      subject
      expect { subject.save.destroy }.not_to change { _redis.keys.sort }
    end
  end

  describe '.exists?' do
    let(:result) { described_class.exists?(topic: topic, subscriber: subscriber_a) }

    it 'is false at rest' do
      expect(result).to be_falsey
    end

    it 'is true when saved' do
      record_a.save
      expect(result).to be_truthy
    end
  end

  describe '.find' do
    let(:result) { described_class.find(topic: topic, subscriber: subscriber_a) }

    it 'is false at rest' do
      expect(result).to be_falsey
    end

    it 'is a record when saved' do
      record_a.save
      record_b.save
      expect(result).to eq(record_a)
    end
  end

  describe '.where' do
    shared_examples 'search' do
      it 'returns the correct results' do
        expect { described_class.where(options).to eq(results) } 
      end
    end

    shared_examples 'empty search' do
      let(:results) { Set.new }
      include_examples 'search'
    end

    context 'lookup by topic' do
      let(:options) {{ topic: topic }}

      context 'at rest' do
        include_examples 'empty search'
      end

      context 'with data' do
        let(:results) { [record_a, record_b].to_set }
        before { record_a.save ; record_b.save }
        include_examples 'search'
      end
    end

    context 'lookup by subscriber' do
      let(:options) {{ subscriber: subscriber_b }}

      context 'at rest' do
        include_examples 'empty search'
      end

      context 'with data' do
        let(:results) { [record_b].to_set }
        before { record_a.save ; record_b.save }
        include_examples 'search'
      end
    end
  end
end
