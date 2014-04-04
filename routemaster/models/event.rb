require 'routemaster/models'
require 'routemaster/models/callback_url'
require 'routemaster/mixins/assert'

module Routemaster::Models
  class Event
    include Routemaster::Mixins::Assert

    VALID_TYPES = %w(create update delete noop)

    attr_reader :topic, :type, :url, :timestamp

    def initialize(topic:, type:, url:, timestamp: nil)
      _assert VALID_TYPES.include?(type), 'bad event type'
      @topic     = topic
      @type      = type
      @url       = CallbackURL.new(url)
      @timestamp = timestamp || Routemaster.now
    end

    def marshal_dump
      [@topic, @type, @url, @timestamp]
    end

    def marshal_load(args)
      initialize(topic: args[0], type: args[1], url: args[2], timestamp: args[3])
    end

    def ==(other)
      other.topic     == topic
      other.type      == type &&
      other.timestamp == timestamp &&
      other.url       == url
    end
  end
end
