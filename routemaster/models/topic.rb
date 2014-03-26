require 'routemaster/models/base'
require 'routemaster/models/event'
require 'routemaster/errors'

module Routemaster::Models
  class Topic < Routemaster::Models::Base
    TopicClaimedError = Class.new(Exception)

    def initialize(name:, publisher:)
      @name = Name.new(name)
      @publisher = Publisher.new(publisher)

      return if conn.hsetnx(_key, 'publisher', publisher)
      raise TopicClaimedError unless conn.hget(_key, 'publisher') == @publisher
    end

    def publisher
      @publisher
    end

    def subscribers
      conn.smembers("#{_key}/subscribers")
    end

    def push(event)
      conn.rpush(_key_events, event.dump)
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

    private

    def _key
      @_key ||= 'topic/#{@name}'
    end

    def _key_events
      @_key_events ||= "#{_key}/events"
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
