require 'routemaster/models'
require 'routemaster/models/callback_url'
require 'routemaster/models/message'
require 'routemaster/mixins/assert'
require 'base64'

module Routemaster
  module Models
    class Event < Message
      include Mixins::Assert
      extend  Mixins::Assert

      VALID_TYPES = %w(create update delete noop)

      attr_reader :topic, :type, :url

      def initialize(**options)
        super
        _assert VALID_TYPES.include?(options[:type]), 'bad event type'
        @topic     = options.fetch(:topic)
        @type      = options.fetch(:type)
        @url       = CallbackURL.new options.fetch(:url)
      end

      def to_hash
        super.merge(topic: @topic, type: @type, url: @url)
      end

      def inspect
        '<%s %s:%s url="%s">' % [
          self.class.name.demodulize,
          @topic, @type, @url,
        ]
      end
    end
  end
end
