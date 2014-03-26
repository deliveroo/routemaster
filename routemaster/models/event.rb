require 'routemaster/models'

class Routemaster::Models::Event
  VALID_TYPES = %w(create update delete noop)
  LOAD_REGEXP = Regexp.new("^(?<type>#{VALID_TYPES.join('|')}),(?<url>.*)$")

  def initialize(type:, url:)
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
    new(type: match['type'], url: match['url'])
  end
end
