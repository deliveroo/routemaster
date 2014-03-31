require 'routemaster/models/base'
require 'routemaster/models/event'
require 'routemaster/errors'

module Routemaster::Models
  class Topic < Routemaster::Models::Base
    TopicClaimedError = Class.new(Exception)

    attr_reader :name, :publisher

    def initialize(name:, publisher:)
      @name = Name.new(name)
      @publisher = Publisher.new(publisher)

      conn.hsetnx(_key, 'publisher', publisher)
      conn.sadd('topics', name)
      raise TopicClaimedError unless conn.hget(_key, 'publisher') == @publisher
    end

    def subscribers
      conn.smembers("#{_key}/subscribers")
    end

    def push(event)
      conn.rpush(_key_events, event.dump)
      conn.publish(_key_channel, 'ping')
    end

    def peek
      raw_event = conn.lindex(_key_events, 0)
      return if raw_event.nil?
      Event.load(raw_event)
    end

    def pop
      raw_event = conn.lpop(_key_events)
      return if raw_event.nil?
      Event.load(raw_event)
    end

    def ==(other)
      name == other.name &&
      publisher == other.publisher
    end

    def self.all
      conn.smembers('topics').map do |n|
        p = conn.hget("topic/#{n}", 'publisher')
        new(name: n, publisher: p)
      end
    end

    private

    def _key
      @_key ||= "topic/#{@name}"
    end

    def _key_events
      @_key_events ||= "#{_key}/events"
    end

    def _key_channel
      @_key_channel ||= "#{_key}/pubsub"
    end

    class Name < String
      def initialize(str)
        raise ArgumentError unless str.kind_of?(String)
        raise ArgumentError unless str =~ /[a-z_]{1,32}/
        super
      end
    end

    class Publisher < String
      def initialize(str)
        raise ArgumentError unless str.kind_of?(String)
        raise ArgumentError unless str =~ /[a-z0-9:_-]{1,64}/
        super
      end
    end
  end
end
