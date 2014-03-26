require 'routemaster/models'
require 'URI'

class Routemaster::Models::Event
  VALID_TYPES = %w(create update delete noop)
  LOAD_REGEXP = Regexp.new("^(?<type>#{VALID_TYPES.join('|')}),(?<t>[0-9a-f]{12}),(?<url>.*)$")

  attr_reader :type, :url, :timestamp

  def initialize(type:, url:, timestamp: nil)
    raise ArgumentError.new('bad event type') unless VALID_TYPES.include?(type)
    parsed_url = URI.parse(url)
    raise ArgumentError.new('entity URL is not HTTPS') unless parsed_url.scheme == 'https'
    raise ArgumentError.new('entity URL has query string') unless parsed_url.query.nil?
    @type = type
    @url = url
    @timestamp ||= current_timestamp
  end

  def dump
    "#{@type},#{@timestamp},#{@url}"
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
