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

      def initialize(original_data)
        _assert original_data.kind_of?(Hash)
        data = sanitize(original_data)
        blob = MessagePack.dump(data)
        _assert blob.length <= MAX_EVENT_DATA, 'event data too large'
        super
      end

      def ==(other)
        other.kind_of?(self.class) && __getobj__ == other.__getobj__
      end

      private

      def sanitize(data)
        data.each_with_object({}) do |(key, value), hash|
          case value
          when BigDecimal
            hash[key] = value.to_f
          when Hash
            hash[key] = sanitize(value)
          else
            hash[key] = value
          end
        end
      end
    end
  end
end

