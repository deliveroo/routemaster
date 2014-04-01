require 'routemaster/models'
require 'routemaster/models/callback_url'
require 'routemaster/mixins/assert'

module Routemaster::Models
  class Event
    include Routemaster::Mixins::Assert

    VALID_TYPES = %w(create update delete noop)
    LOAD_REGEXP = Regexp.new("^(?<topic>[a-z_]+),(?<type>#{VALID_TYPES.join('|')}),(?<t>[0-9a-f]{11}),(?<url>.*)$")

    attr_reader :topic, :type, :url, :timestamp

    def initialize(topic:, type:, url:, timestamp: nil)
      _assert VALID_TYPES.include?(type), 'bad event type'
      @topic     = topic
      @type      = type
      @url       = CallbackURL.new(url)
      @timestamp = timestamp || Routemaster.now
    end

    def dump
      "#{@topic},#{@type},#{@timestamp.to_s(16)},#{@url}"
    end

    def ==(other)
      other.topic     == topic
      other.type      == type &&
      other.timestamp == timestamp &&
      other.url       == url
    end

    def self.load(string)
      return unless match = LOAD_REGEXP.match(string)
      new(
        topic:     match['topic'],
        type:      match['type'],
        url:       match['url'],
        timestamp: match['t'].to_i(16))
    end
  end
end
