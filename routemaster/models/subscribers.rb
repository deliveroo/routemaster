require 'routemaster/models'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/assert'
require 'routemaster/mixins/log'

module Routemaster::Models
  # An enumerable collection of Subscriber
  class Subscribers
    include Routemaster::Mixins::Redis
    include Routemaster::Mixins::Assert
    include Routemaster::Mixins::Log
    include Enumerable

    def initialize(topic)
      @topic = topic
    end

    def include?(subscriber)
      _redis.sismember(_key, subscriber.subscriber)
    end

    def replace(subscribers)
      new = subscribers
      old = to_a
      (old - new).each { |sub| remove(sub) }
      (new - old).each { |sub| add(sub) }
      self
    end

    def add(subscriber)
      _change(:add, subscriber)
    end

    def remove(subscriber)
      _change(:rem, subscriber)
    end


    # yields Subscribers
    def each
      _redis.smembers(_key).each do |name|
        yield Subscriber.new(subscriber: name)
      end
      self
    end

    private

    def _change(action, subscriber)
      _assert subscriber.kind_of?(Subscriber), "#{subscriber} not a Subscriber"
      if _redis.public_send("s#{action}", _key, subscriber.subscriber)
        _log.info { "topic '#{@topic.name}': #{action} subscriber '#{subscriber.subscriber}'" }
      end
      self
    end

    def _key
      @_key ||= "subscribers:#{@topic.name}"
    end
  end
end
