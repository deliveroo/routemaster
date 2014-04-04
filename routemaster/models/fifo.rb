require 'routemaster/models/base'
require 'routemaster/models/event'

module Routemaster::Models
  # A first-in, first-out list of marshalled Ruby objects
  class Fifo < Routemaster::Models::Base
    BLOCK_TIMEOUT_SECONDS = 1

    def initialize(name)
      @name = name
    end

    def push(data)
      conn.rpush(_key_events, Marshal.dump(data))
    end

    def peek
      raw = conn.lindex(_key_events, 0)
      return if raw.nil?
      Marshal.load(raw)
    end

    def pop
      raw = conn.lpop(_key_events)
      return if raw.nil?
      Marshal.load(raw)
    end

    def block_pop
      raw = conn.blpop(_key_events, BLOCK_TIMEOUT_SECONDS)
      return if raw.nil?
      _assert(raw[0] == _key_events)
      Marshal.load(raw[1])
    end

    def length
      conn.llen(_key_events)
    end

    private

    def _key
      @_key ||= "fifo/#{@name}"
    end

    def _key_events
      @_key_events ||= "#{_key}/data"
    end
  end
end

