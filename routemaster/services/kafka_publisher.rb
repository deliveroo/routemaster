module Routemaster
  module Services
    class KafkaPublisher
      PUBLISH_ALL_TOPICS = ENV['DOUBLE_DISPATCH_ALL_TOPICS_TO_KAFKA'].to_s.downcase == 'true'
      PUBLISH_TOPICS_SUBSET = begin
        hash = Hash.new(false)
        topics = ENV['DOUBLE_DISPATCH_THESE_TOPICS_TO_KAFKA'].to_s.split(',')
        topics.each { |t| hash[t.strip.downcase] = true }
        hash.freeze
      end

      def initialize(options = {})
        @topic = options.fetch(:topic)
        @event = options.fetch(:event)
      end

      def call
        publish_to_kafka if should_publish?
      end

      private

      def should_publish?
        PUBLISH_ALL_TOPICS || PUBLISH_TOPICS_SUBSET[@topic.name]
      end

      def publish_to_kafka
        # Code goes here
      end
    end
  end
end
