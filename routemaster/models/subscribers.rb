require 'routemaster/models'
require 'routemaster/mixins/connection'
require 'routemaster/mixins/assert'

module Routemaster::Models
  class Subscribers
    include Routemaster::Mixins::Connection
    include Routemaster::Mixins::Assert
    include Enumerable

    def initialize(topic)
      @topic = topic
    end

    def add(subscription)
      _assert subscription.kind_of?(Subscription)
      conn.sadd(_key, subscription.subscriber)
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
