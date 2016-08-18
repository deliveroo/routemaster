require 'spec_helper'
require 'spec/support/persistence'
require 'routemaster/services/update_subscription_topics'
require 'routemaster/models/subscription'
require 'routemaster/models/topic'

describe Routemaster::Services::UpdateSubscriptionTopics do
  let(:subscription) { Routemaster::Models::Subscription.new(subscriber: 'alice') }
  let(:topic_a) { Routemaster::Models::Topic.new(name: 'topic_a', publisher: 'bob') }
  let(:topic_b) { Routemaster::Models::Topic.new(name: 'topic_b', publisher: 'bob') }
  let(:topic_c) { Routemaster::Models::Topic.new(name: 'topic_c', publisher: 'bob') }
  let(:topics) { [] }

  subject { described_class.new subscription: subscription, topics: topics }

  def current_topics
    subscription.topics.map(&:name).sort
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
      topic_a.subscribers.add subscription
      topic_b.subscribers.add subscription
    end

    it 'can remove all subscriptions' do
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
