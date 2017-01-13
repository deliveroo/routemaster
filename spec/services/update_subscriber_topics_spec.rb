require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/services/update_subscriber_topics'
require 'routemaster/models/subscriber'
require 'routemaster/models/subscription'
require 'routemaster/models/topic'

describe Routemaster::Services::UpdateSubscriberTopics do
  let(:subscriber) { Routemaster::Models::Subscriber.new(name: 'alice').save }
  let(:topic_a) { Routemaster::Models::Topic.new(name: 'topic_a', publisher: 'bob') }
  let(:topic_b) { Routemaster::Models::Topic.new(name: 'topic_b', publisher: 'bob') }
  let(:topic_c) { Routemaster::Models::Topic.new(name: 'topic_c', publisher: 'bob') }
  let(:topics) { [] }

  subject { described_class.new subscriber: subscriber, topics: topics }

  def current_topics
    subscriber.topics.map(&:name).sort
  end

  it 'passes when no topics' do
    expect { subject.call }.not_to change { current_topics }
  end

  it 'adds the specified topics' do
    topics.replace [topic_c, topic_a]
    expect { subject.call }.to change { current_topics }.from(%w[]).to(%w[topic_a topic_c])
  end

  context 'when topics already are subscribed' do
    before do
      Routemaster::Models::Subscription.new(topic: topic_a, subscriber: subscriber).save
      Routemaster::Models::Subscription.new(topic: topic_b, subscriber: subscriber).save
    end

    it 'can remove all subscribers' do
      expect { subject.call }.to change { current_topics }.to %w[]
    end

    it 'can modify the list' do
      topics.replace [topic_b, topic_c]
      expect { subject.call }.to change { current_topics }.to %w[topic_b topic_c]
    end

    it 'can remove from the list' do
      topics.replace [topic_a]
      expect { subject.call }.to change { current_topics }.to %w[topic_a]
    end

    it 'can add to the list' do
      topics.replace [topic_a, topic_b, topic_c]
      expect { subject.call }.to change { current_topics }.to %w[topic_a topic_b topic_c]
    end
  end
end
