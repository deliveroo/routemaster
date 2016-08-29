require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/subscriber'
require 'routemaster/models/subscribers'
require 'routemaster/models/queue'
require 'routemaster/models/message'
require 'routemaster/models/topic'

describe Routemaster::Models::Subscriber do
  let(:topic) { Routemaster::Models::Topic.new(name: 'widgets', publisher: 'alice') }
  let(:redis) { Object.new.extend(Routemaster::Mixins::Redis)._redis }
  subject { described_class.new(name: 'bob') }

  describe '#initialize' do
    it 'passes' do
      expect { subject }.not_to raise_error
    end
  end

  describe '#destroy' do
    before { topic }

    let(:perform) do
      subject.callback = 'https://example.com'
      subject.uuid = '0e959830-6de3-11e6-8b8f-572d810770de'
      topic.subscribers.add subject
      subject.destroy
    end

    it 'passes' do
      expect { perform }.not_to raise_error
    end

    it 'removes' do
      perform
      expect(described_class.find('alice')).to be_nil 
    end

    it 'cleans up' do
      expect { subject.destroy }.not_to change { redis.keys }
    end
  end

  describe '#timeout=' do
    it 'accepts integers' do
      expect { subject.timeout = 123 }.not_to raise_error
    end

    it 'rejects strings' do
      expect { subject.timeout = '123' }.to raise_error(ArgumentError)
    end

    it 'rejects negatives' do
      expect { subject.timeout = -123 }.to raise_error(ArgumentError)
    end

  end

  describe '#timeout' do
    it 'returns a default value if unset' do
      expect(subject.timeout).to eq(described_class::DEFAULT_TIMEOUT)
    end

    it 'returns an integer' do
      subject.timeout = 123
      expect(subject.timeout).to eq(123)
    end
  end

  describe '.each' do

    it 'does not yield when no subscribers are present' do
      expect { |b| described_class.each(&b) }.not_to yield_control
    end

    it 'yields subscribers' do
      a = described_class.new(name: 'alice')
      b = described_class.new(name: 'bob')

      expect { |b| described_class.each(&b) }.to yield_control.twice
    end
  end

  describe '#topics' do

    let(:properties_topic) do
      Routemaster::Models::Topic.new(name: 'properties', publisher: 'demo')
    end

    let(:property_photos_topic) do
      Routemaster::Models::Topic.new(name: 'photos', publisher: 'demo')
    end

    before do
      subscriber1 = Routemaster::Models::Subscribers.new(properties_topic)
      subscriber1.add(subject)
      subscriber2 = Routemaster::Models::Subscribers.new(property_photos_topic)
      subscriber2.add(subject)
    end

    it 'returns an array of associated topics' do
      expect(subject.topics.map{|x|x.name}.sort)
        .to eql(['photos','properties'])
    end
  end

  describe '#all_topics_count' do
    let(:properties_topic) do
      Routemaster::Models::Topic.new({
        name: 'properties',
        publisher: 'demo'
      })
    end
    let(:property_photos_topic) do
      Routemaster::Models::Topic.new({
        name: 'photos',
        publisher: 'demo'
      })
    end

    before do
      subscriber1 = Routemaster::Models::Subscribers.new(properties_topic)
      subscriber1.add(subject)
      subscriber2 = Routemaster::Models::Subscribers.new(property_photos_topic)
      subscriber2.add(subject)
    end

    it 'should sum the cumulative totals for all associated topics' do
      allow(subject)
        .to receive(:topics)
        .and_return([properties_topic, property_photos_topic])
      allow(properties_topic)
        .to receive(:get_count)
        .and_return(100)
      allow(property_photos_topic)
        .to receive(:get_count)
        .and_return(200)

      expect(subject.all_topics_count).to eql 300
    end
  end

  describe '#queue' do
    it 'is mine' do
      expect(subject.queue.subscriber).to eq(subject)
    end
  end

end
