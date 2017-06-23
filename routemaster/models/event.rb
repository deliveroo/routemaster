require 'routemaster/models'
require 'routemaster/models/callback_url'
require 'routemaster/models/event_data'
require 'routemaster/models/message'
require 'routemaster/mixins/assert'
require 'core_ext/string'

module Routemaster
  module Models
    class Event < Message
      include Mixins::Assert
      extend  Mixins::Assert

      VALID_TYPES = %w(create update delete noop)

      attr_reader :topic, :type, :url, :data

      def initialize(**options)
        super
        @type      = options.fetch(:type, nil)
        @url       = CallbackURL.new options[:url]
        @topic     = options.fetch(:topic)
        @data      = EventData.build options[:data]

        _assert VALID_TYPES.include?(@type), 'bad event type'
        _assert options[:timestamp].to_i <= Routemaster.now, 'timestamp is from the future'
      end

      def to_hash
        super.merge(topic: @topic, type: @type, url: @url, data: @data)
      end

      def inspect
        '<%s %s:%s url="%s" data=%s>' % [
          self.class.name.demodulize,
          @topic, @type, @url, @data.inspect,
        ]
      end
    end
  end
end
