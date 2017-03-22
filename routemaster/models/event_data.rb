require 'routemaster/models'
require 'routemaster/mixins/assert'
require 'msgpack'

module Routemaster
  module Models
    # Value object for event data blobs.
    # Fails on construction if the serialized representation is too long.
    class EventData < SimpleDelegator
      include Mixins::Assert

      MAX_EVENT_DATA = ENV.fetch('ROUTEMASTER_MAX_EVENT_DATA').to_i

      class << self
        private :new

        def build(data)
          return if data.nil?
          new(data)
        end
      end

      def initialize(data)
        _assert data.kind_of?(Hash)
        blob = MessagePack.dump(data)
        _assert blob.length <= MAX_EVENT_DATA, 'event data too large'
        super
      end

      def ==(other)
        other.kind_of?(self.class) && __getobj__ == other.__getobj__
      end
    end
  end
end

