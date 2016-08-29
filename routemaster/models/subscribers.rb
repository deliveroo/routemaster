require 'routemaster/models'
require 'routemaster/models/subscription'
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
      Subscription.exists?(subscriber: subscriber, topic: @topic)
    end

    def replace(subscribers)
      new = subscribers
      old = to_a
      (old - new).each { |sub| remove(sub) }
      (new - old).each { |sub| add(sub) }
      self
    end

    def add(subscriber)
      Subscription.new(subscriber: subscriber, topic: @topic).save
    end

    def remove(subscriber)
      Subscription.new(subscriber: subscriber, topic: @topic).destroy
    end


    # yields Subscribers
    def each
      Subscription.where(topic: @topic).each do |s|
        yield s.subscriber
      end
      self
    end
  end
end
