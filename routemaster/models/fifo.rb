require 'routemaster/models/base'
require 'routemaster/models/event'

module Routemaster::Models
  class Fifo < Routemaster::Models::Base

    def initialize(name)
      @name = name
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

    def length
      conn.llen(_key_events)
    end

    private

    def _key
      @_key ||= "fifo/#{@name}"
    end

    def _key_events
      @_key_events ||= "#{_key}/events"
    end
  end
end

