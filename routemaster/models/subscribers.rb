require 'routemaster/models'
require 'routemaster/mixins/connection'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/log'

module Routemaster::Models
  class Subscribers
    include Routemaster::Mixins::Connection
    include Routemaster::Mixins::Assert
    include Routemaster::Mixins::Log
    include Enumerable

    def initialize(topic)
      @topic = topic
    end

    def add(subscription)
      _assert subscription.kind_of?(Subscription)
      if conn.sadd(_key, subscription.subscriber)
        _log.info { "new subscriber '#{subscription.subscriber}' to '#{@topic.name}'" }
      end

      # bind the subscription's RabbitMQ queue to the topic's exchange
      subscription.queue.bind(@topic.exchange)
    end

    # yields Subscriptions
    def each
      conn.smembers(_key).each do |name|
        yield Subscription.new(subscriber: name)
      end
    end

    private

    def _key
      @_key ||= "subscribers/#{@topic.name}"
    end
  end
end
