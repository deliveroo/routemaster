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


      def initialize(name:, publisher:)
        @name      = Name.new(name)
        @publisher = Publisher.new(publisher) if publisher

        _redis.sadd(_index_key, name)

        return if publisher.nil?

        if _redis.hsetnx(_key(@name), 'publisher', publisher)
          _log.info { "topic '#{@name}' claimed by '#{@publisher}'" }
        end

        current_publisher = _redis.hget(_key(@name), 'publisher')
        unless _redis.hget(_key(@name), 'publisher') == @publisher
          raise TopicClaimedError.new("topic claimed by #{current_publisher}")
        end
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
        def all
          _redis.smembers(_index_key).map do |n|
            p = _redis.hget("topic:#{n}", 'publisher')
            new(name: n, publisher: p)
          end
        end

        def find(name)
          return unless _redis.sismember(_index_key, name)
          publisher = _redis.hget("topic:#{name}", 'publisher')
          new(name: name, publisher: publisher)
        end
      end
      extend ClassMethods


      module SharedMethods
        private

        def _key(name)
          "topic:#{@name}"
        end

        def _index_key
          'topics'
        end
      end
      include SharedMethods
      extend  SharedMethods


      private


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
