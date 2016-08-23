require 'routemaster/models'
require 'routemaster/mixins/log'
require 'routemaster/mixins/assert'

module Routemaster
  module Models
    # Abstract base calss for messages that transits on a queue
    class Message
      include Mixins::Log
      include Mixins::Assert

      attr_reader :uid, :timestamp
      
      def initialize(**options)
        @uid       = options.fetch(:uid) { SecureRandom.uuid }
        @timestamp = options.fetch(:timestamp) { Routemaster.now }
        @status    = nil

        _assert @timestamp
      end

      def to_hash
        { timestamp: @timestamp }
      end

      def inspect
        "<#{self.class.name} @uid=\"#{@uid}\">"
      end

      # Messages are equal if their _data_ (excluding UID) and timestamps are
      # equal.
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
