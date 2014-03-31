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

    def add(queue)
      _assert queue.kind_of?(Queue)
      conn.sadd(_key, queue.subscriber)
    end

    # yields Queues
    def each
      conn.smembers(_key).each do |name|
        yield Queue.new(subscriber: name)
      end
    end

    private

    def _key
      @_key ||= "subscribers/#{@topic.name}"
    end
  end
end
