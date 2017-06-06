require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/models/subscriber'
require 'routemaster/models/message'
require 'routemaster/models/topic'

describe Routemaster::Models::Subscriber do
  let(:topic) { Routemaster::Models::Topic.find_or_create!(name: 'widgets', publisher: 'alice') }
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
      Routemaster::Models::Subscription.new(topic: topic, subscriber: subject).save
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
      expect { subject.destroy }.not_to change { redis.keys.sort }
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
      a = described_class.new(name: 'alice').save
      b = described_class.new(name: 'bob').save

      expect { |b| described_class.each(&b) }.to yield_control.twice
    end
  end

  describe '#topics' do

    let(:properties_topic) do
      Routemaster::Models::Topic.find_or_create!(name: 'properties', publisher: 'demo')
    end

    let(:property_photos_topic) do
      Routemaster::Models::Topic.find_or_create!(name: 'photos', publisher: 'demo')
    end

    before do
      Routemaster::Models::Subscription.new(topic: properties_topic, subscriber: subject).save
      Routemaster::Models::Subscription.new(topic: property_photos_topic, subscriber: subject).save
    end

    it 'returns an array of associated topics' do
      expect(subject.topics.map{|x|x.name}.sort)
        .to eql(['photos','properties'])
    end
  end

  describe '.find' do
    let(:perform) { described_class.find('bob') }

    context 'when the subscriber does not exist' do
      it { expect(perform).to be_nil }
    end

    context 'when the subscriber exists' do
      before { subject.save }
      it { expect(perform).to eq(subject) }
    end
  end

  describe '.where' do
    let(:names) { %w[alice bob] }

    let!(:subs) {
      names.map do |n|
        sub = described_class.new(name: n)
        sub.uuid = "#{n}-secret"
        sub.save
      end
    }

    it 'returns a single subscriber' do
      expect(described_class.where(name: 'alice')).to eq([subs.first])
    end

    it 'loads metadata' do
      sub = described_class.where(name: 'alice').first
      expect(sub.uuid).to eq('alice-secret')
    end

    it 'returns multiple subscribers' do
      expect(described_class.where(name: %w[alice bob]).length).to eq(2)
    end

    it 'ignores missing names' do
      expect(described_class.where(name: %w[alice charlie]).length).to eq(1)
    end
  end

  describe 'attributes' do
    describe '#health_points' do
      it 'retuns an integer and defalts to 100' do
        expect(subject.health_points).to eq(100)
      end
    end

    describe '#change_health_by(offset)' do
      before do
        expect(subject.health_points).to eq(100)
      end

      def reloaded_subscriber
        described_class.new(name: subject.name)
      end

      it 'changes the value by the positive or negative offset' do
        expect {
          subject.change_health_by -42
        }.to change {
          reloaded_subscriber.health_points
        }.from(100).to(58)

        expect {
          subject.change_health_by 30
        }.to change {
          reloaded_subscriber.health_points
        }.from(58).to(88)
      end


      it 'never exceeds 100' do
        subject.change_health_by -10

        expect {
          subject.change_health_by 30
        }.to change {
          reloaded_subscriber.health_points
        }.from(90).to(100)

        expect {
          subject.change_health_by 30
        }.not_to change {
          reloaded_subscriber.health_points
        }
      end


      it 'never goes below 0' do
        expect {
          subject.change_health_by -200
        }.to change {
          reloaded_subscriber.health_points
        }.from(100).to(0)
      end
    end
  end
end
