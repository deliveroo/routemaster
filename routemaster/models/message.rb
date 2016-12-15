require 'routemaster/models'
require 'routemaster/mixins/log'
require 'routemaster/mixins/assert'

module Routemaster
  module Models
    # Abstract base class for messages that transits on a queue
    class Message
      include Mixins::Log
      include Mixins::Assert

      attr_reader :timestamp
      
      def initialize(**options)
        @timestamp = options.fetch(:timestamp) { Routemaster.now }
        @status    = nil

        _assert @timestamp
      end

      def to_hash
        { timestamp: @timestamp }
      end

      def inspect
        "<#{self.class.name}\">"
      end

      # Messages are equal if their data and timestamps are equal.
      def ==(other)
        to_hash == other.to_hash
      end

      Kill = Class.new(self)
      Garbled = Class.new(self)

      class Ping < self
        attr_reader :data

        def initialize(**options)
          super(**options)
          @data = options.fetch(:data, nil)
        end

        def to_hash
          super.merge(data: @data)
        end
      end
    end
  end
end
