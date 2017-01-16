require 'routemaster/models/base'
require 'routemaster/models/event'
require 'routemaster/models/user'
require 'routemaster/models/message'
require 'routemaster/models/subscription'
require 'routemaster/services/codec'
require 'forwardable'

module Routemaster
  module Models
    class Topic < Base
      TopicClaimedError = Class.new(Exception)

      attr_reader :name, :publisher


      def initialize(name:, publisher: nil)
        @name      = Name.new(name)
        @publisher = Publisher.new(publisher) if publisher
      end


      def destroy
        _redis.multi do |m|
          m.srem(_index_key, name)
          m.del(_key(@name))
        end
      end


      def subscribers
        Subscription.where(topic: self).map(&:subscriber)
      end


      def ==(other)
        name == other.name
      end


      def get_count
        _redis.hget(_key(@name), 'counter').to_i
      end


      def increment_count
        _redis.hincrby(_key(@name), 'counter', 1)
      end


      def inspect
        "<#{self.class.name} name=#{@name}>"
      end


      module ClassMethods
        include Mixins::Log

        def all
          _redis.smembers(_index_key).map do |n|
            p = _redis.hget("topic:#{n}", 'publisher')
            new(name: n, publisher: p)
          end
        end

        def find(name)
          return unless _redis.sismember(_index_key, name)
          publisher = _redis.hget(_key(name), 'publisher')
          new(name: name, publisher: publisher)
        end

        def find_or_create!(name:, publisher: nil)
          added, claimed, actual_publisher = _redis_lua_run(
            'topic_find_or_create',
            keys: [_index_key, _key(name)],
            argv: [name, publisher])

          if publisher && actual_publisher != publisher
            raise TopicClaimedError.new("topic already claimed by #{actual_publisher}")
          end
          _log.info { "topic '#{name}' created" } if added > 0
          _log.info { "topic '#{name}' claimed by '#{publisher}'" } if claimed > 0
          
          new(name: name, publisher: actual_publisher)
        end
      end
      extend ClassMethods


      module SharedMethods
        private

        def _key(name)
          "topic:#{name}"
        end

        def _index_key
          'topics'
        end
      end
      include SharedMethods
      extend  SharedMethods


      class Name < String
        def initialize(str)
          raise ArgumentError unless str.kind_of?(String)
          raise ArgumentError unless str =~ /^[a-z_]{1,64}$/
          super
        end
      end

      Publisher = Class.new(User)
    end
  end
end
