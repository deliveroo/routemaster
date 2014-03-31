require 'routemaster/models'
require 'routemaster/models/callback_url'
require 'routemaster/mixins/assert'

module Routemaster::Models
  class Event
    include Routemaster::Mixins::Assert

    VALID_TYPES = %w(create update delete noop)
    LOAD_REGEXP = Regexp.new("^(?<type>#{VALID_TYPES.join('|')}),(?<t>[0-9a-f]{12}),(?<url>.*)$")

    attr_reader :type, :url, :timestamp

    def initialize(type:, url:, timestamp: nil)
      _assert VALID_TYPES.include?(type), 'bad event type'
      @type = type
      @url = CallbackURL.new(url)
      @timestamp = timestamp || current_timestamp
    end

    def dump
      "#{@type},#{@timestamp},#{@url}"
    end

    def ==(other)
      other.type == type &&
      other.timestamp == timestamp &&
      other.url == url
    end

    def self.load(string)
      return unless match = LOAD_REGEXP.match(string)
      new(type: match['type'], url: match['url'], timestamp: match['t'])
    end

    private

    def current_timestamp
      "%012x" % (Time.now.utc.to_f * 1e3)
    end
  end
end
