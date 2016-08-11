require 'routemaster/models/base'
require 'routemaster/models/event'
require 'routemaster/models/user'
require 'routemaster/models/subscribers'
require 'forwardable'

module Routemaster::Models
  class Topic < Routemaster::Models::Base
    TopicClaimedError = Class.new(Exception)

    attr_reader :name, :publisher

    def initialize(name:, publisher:)
      @name      = Name.new(name)
      @publisher = Publisher.new(publisher) if publisher

      _redis.sadd('topics', name)

      return if publisher.nil?

      if _redis.hsetnx(_key, 'publisher', publisher)
        _log.info { "new topic '#{@name}' from '#{@publisher}'" }
      end

      current_publisher = _redis.hget(_key, 'publisher')
      unless _redis.hget(_key, 'publisher') == @publisher
        raise TopicClaimedError.new("topic claimed by #{current_publisher}")
      end
    end

    def subscribers
      @_subscribers ||= Subscribers.new(self)
    end

    def ==(other)
      name == other.name
    end

    def self.all
      _redis.smembers('topics').map do |n|
        p = _redis.hget("topic/#{n}", 'publisher')
        new(name: n, publisher: p)
      end
    end

    def self.find(name)
      publisher = _redis.hget("topic/#{name}", 'publisher')
      return if publisher.nil?
      new(name: name, publisher: publisher)
    end

    def push(event)
      _assert event.kind_of?(Event), 'can only push Event'
      _redis.hset(_key, 'last_event', event.dump)
      _exchange.publish(event.dump, persistent: true)
      increment_count
    end

    def last_event
      raw = _redis.hget(_key, 'last_event')
      return if raw.nil?
      Event.load(raw)
    end

    # ideally this would not be exposed, but binding topics
    # and subscriptions requires accessing this.
    def exchange ; _exchange ; end

    def get_count
      _redis.get(topic_counter_name).to_i
    end

    private

    def increment_count
      _redis.incr(topic_counter_name)
    end

    def topic_counter_name
      "#{@name}_cumulative_count"
    end

    def _key
      @_key ||= "topic/#{@name}"
    end

    def _exchange
      @_exchange ||= bunny.fanout(_bunny_name(@name), durable: true)
    end

    class Name < String
      def initialize(str)
        raise ArgumentError unless str.kind_of?(String)
        raise ArgumentError unless str =~ /^[a-z_]{1,64}$/
        super
      end
    end

    Publisher = Class.new(User)
  end
end
