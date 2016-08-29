require 'routemaster/services'
require 'routemaster/models/subscription'

module Routemaster
  module Services
    # Update the list of topics subscribed to by a subscribers.
    # Does _not_ e.g. remove events regarding an unsubscribed topic
    # from the current queues
    class UpdateSubscriberTopics
      def initialize(subscriber:, topics: [])
        @subscriber = subscriber
        @topics = topics
      end
      
      def call
        # list current topics
        old_topics = @subscriber.topics
        
        @topics.reject { |t| old_topics.include?(t) }.each do |topic|
          Models::Subscription.new(topic: topic, subscriber: @subscriber).save
        end

        old_topics.reject { |t| @topics.include?(t) }.each do |topic|
          Models::Subscription.find(topic: topic, subscriber: @subscriber)&.destroy
        end
      end
    end
  end
end
