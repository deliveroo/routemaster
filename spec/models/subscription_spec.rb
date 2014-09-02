require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/subscription'
require 'routemaster/models/subscribers'
require 'routemaster/models/topic'

describe Routemaster::Models::Subscription do
  subject { described_class.new(subscriber: 'bob') }

  describe '#initialize' do
    it 'passes' do
      expect { subject }.not_to raise_error
    end
  end

  describe '#timeout=' do
    it 'accepts integers' do
      expect { subject.timeout = 123 }.not_to raise_error
    end

    it 'rejects strings' do
      expect { subject.timeout = '123' }.to raise_error
    end

    it 'rejects negatives' do
      expect { subject.timeout = -123 }.to raise_error
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

    it 'does not yield when no subscriptions are present' do
      expect { |b| described_class.each(&b) }.not_to yield_control
    end

    it 'yields subscriptions' do
      a = described_class.new(subscriber: 'alice')
      b = described_class.new(subscriber: 'bob')

      expect { |b| described_class.each(&b) }.to yield_control.twice
    end
  end

  describe '.topics' do

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
      expect(subject.topics.map{|x|x.name}).to eql(['properties','photos'])
    end
  end

  describe '.all_topics_count' do

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
      expect(subject)
        .to receive(:topics)
        .and_return([properties_topic, property_photos_topic])
      expect(properties_topic)
        .to receive(:get_count)
        .and_return(100)
      expect(property_photos_topic)
        .to receive(:get_count)
        .and_return(200)

      expect(subject.all_topics_count).to eql 300
    end

  end
end
