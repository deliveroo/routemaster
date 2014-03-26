require 'routemaster/models/base'
require 'routemaster/errors'

Routemaster::Errors::TopicClaimed = Class.new(Exception)

class Routemaster::Models::Topic < Routemaster::Models::Base

  def initialize(name:, publisher:)
    @name = Name.new(name)
    @publisher = Publisher.new(publisher)

    return if conn.hsetnx(_key, 'publisher', publisher)
    raise Routemaster::Errors::TopicClaimed unless
      conn.hget(_key, 'publisher') == @publisher
  end

  def publisher
    @publisher
  end

  def subscribers
    conn.smembers("#{_key}/subscribers")
  end

  def push(event:, url:)
    event = Event.new(event, url)
    conn.rpush(_key_events, event.dump)
  end

  def peek
    raw_event = conn.lindex(_key_events, 0)
    return if raw_event.nil?
    Event.load(raw_event)
  end

  private

  def _key
    @_key ||= 'channels/#{@name}'
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

  class Event
    VALID_TYPES = %w(create update delete noop)
    LOAD_REGEXP = Regexp.new("^(?<type>#{VALID_TYPES.join('|')}),(?<url>.*)$")

    def initialize(type, url)
      raise ArgumentError.new('bad event type') unless VALID_TYPES.include?(type)
      parsed_url = URI.parse(url)
      raise ArgumentError.new('entity URL is not HTTPS') unless parsed_url.scheme == 'https'
      raise ArgumentError.new('entity URL has query string') unless parsed_url.query.nil?
      @_type = type
      @_url = url
    end

    def dump
      "#{@_type},#{@_url}"
    end

    def type ; @_type ; end
    def url  ; @_url  ; end

    def self.load(string)
      return unless match = LOAD_REGEXP.match(string)
      new(match['type'], match['url'])
    end
  end
end

