require 'routemaster/services'

module Routemaster
  module Services
    # Update the list of topics subscribed to by a subscribers.
    # Does _not_ e.g. remove event regarding an unsubscribed topic
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
          topic.subscribers.add(@subscriber)
        end

        old_topics.reject { |t| @topics.include?(t) }.each do |topic|
          topic.subscribers.remove(@subscriber)
        end
      end
    end
  end
end
