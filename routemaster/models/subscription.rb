require 'routemaster/models'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/log'

module Routemaster
  module Models
    # The relation between a Subscriber and a Topic
    class Subscription
      include Mixins::Redis
      include Mixins::Assert
      include Mixins::Log

      attr_reader :subscriber, :topic

      def initialize(subscriber:, topic:)
        @subscriber = subscriber
        @topic = topic
      end

      def save
        res = _redis.multi do |m|
          m.sadd _key_topic, @subscriber.name
          m.sadd _key_subscriber, @topic.name
        end
        _log.info { "'#{@subscriber.name}' subscribed to '#{@topic.name}'" } if res.any?
        self
      end

      def destroy
        res = _redis.multi do |m|
          m.srem _key_topic, @subscriber.name
          m.srem _key_subscriber, @topic.name
        end
        _log.info { "'#{@subscriber.name}' unsubscribed from '#{@topic.name}'" } if res.any?
        self
      end

      def ==(other)
        subscriber == other.subscriber && topic == other.topic
      end

      alias_method :eql?, :==

      module ClassMethods
        include Mixins::Assert

        def find(subscriber:, topic:)
          return unless exists?(subscriber: subscriber, topic: topic)
          new(subscriber: subscriber, topic: topic)
        end

        def exists?(subscriber:, topic:)
          _redis.sismember(_key_topic(topic), subscriber.name)
        end

        def where(subscriber: nil, topic: nil)
          _assert(subscriber.nil? ^ topic.nil?, 'exactly one or subscriber or topic must be provided')
          if subscriber
            Set.new _redis.smembers(_key_subscriber(subscriber)).map { |name|
              new(subscriber: subscriber, topic: Topic.find(name))
            }
          else
            Set.new _redis.smembers(_key_topic(topic)).map { |name|
              new(subscriber: Subscriber.find(name), topic: topic)
            }
          end
        end

        private

        def _key_subscriber(subscriber)
          "topics:#{subscriber.name}"
        end

        def _key_topic(topic)
          "subscribers:#{topic.name}"
        end
      end
      extend ClassMethods

      private

      def _key_subscriber
        self.class.send(__method__, @subscriber)
      end

      def _key_topic
        self.class.send(__method__, @topic)
      end
    end
  end
end
