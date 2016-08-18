require 'routemaster/services'

module Routemaster
  module Services
    # Update the list of topics subscribed to by a subscribers.
    # Does _not_ e.g. remove event regarding an unsubscribed topic
    # from the current queues
    class UpdateSubscriptionTopics
      def initialize(subscription:, topics: [])
        @subscription = subscription
        @topics = topics
      end
      
      def call
        # list current topics
        old_topics = @subscription.topics
        
        @topics.reject { |t| old_topics.include?(t) }.each do |topic|
          topic.subscribers.add(@subscription)
        end

        old_topics.reject { |t| @topics.include?(t) }.each do |topic|
          topic.subscribers.remove(@subscription)
        end
      end
    end
  end
end
