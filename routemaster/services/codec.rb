require 'msgpack'
require 'core_ext/hash'
require 'routemaster/services'
require 'routemaster/models/message'
require 'routemaster/models/event'
require 'routemaster/mixins/log'

module Routemaster
  module Services
    # Encodes and decodes messages so they can be stored in Redis.
    class Codec
      include Mixins::Log

      # Produce a Message (or subclass) from a string and a UID
      def load(data)
        code, hash = MessagePack.unpack(data)
        CODE_TO_CLASS[code].new(decode_hash(hash).symbolize_keys)
      rescue MessagePack::UnpackError => e
        _log.warn { "Failed to decode message" }
        _log_exception(e)
        Models::Message::Garbled.new
      end

      # Transforms a message into a string
      def dump(message)
        [
          CLASS_TO_CODE[message.class],
          encode_hash(message.to_hash),
        ].to_msgpack
      end

      private

      def encode_hash(hash)
        transform_hash(KEY_TO_CODE, hash)
      end

      def decode_hash(hash)
        transform_hash(CODE_TO_KEY, hash)
      end

      def transform_hash(map, hash)
        hash.dup.tap do |h|
          h.keys.each do |key|
            h[map[key.to_s]] = h.delete(key)
          end
        end
      end

      CODE_TO_KEY = {
        't' => 'timestamp',
        'o' => 'topic',
        'y' => 'type',
        'u' => 'url',
        'd' => 'data',
      }

      KEY_TO_CODE = Hash[CODE_TO_KEY.to_a.map(&:reverse)]

      CODE_TO_CLASS = {
        'k' => Models::Message::Kill,
        'p' => Models::Message::Ping,
        'e' => Models::Event,
      }

      CLASS_TO_CODE = Hash[CODE_TO_CLASS.to_a.map(&:reverse)]
    end
  end
end
