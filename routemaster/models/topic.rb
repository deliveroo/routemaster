require 'routemaster/models/base'
require 'routemaster/models/event'
require 'routemaster/models/user'
require 'routemaster/models/subscribers'
require 'routemaster/models/fifo'

module Routemaster::Models
  class Topic < Routemaster::Models::Base
    TopicClaimedError = Class.new(Exception)

    attr_reader :name, :publisher

    def initialize(name:, publisher:)
      @name = Name.new(name)
      @publisher = Publisher.new(publisher) if publisher
      conn.sadd('topics', name)

      return if publisher.nil?

      conn.hsetnx(_key, 'publisher', publisher)

      current_publisher = conn.hget(_key, 'publisher')
      unless conn.hget(_key, 'publisher') == @publisher
        raise TopicClaimedError.new("topic claimed by #{current_publisher}")
      end
    end

    def subscribers
      @_subscribers ||= Subscribers.new(self)
    end

    def ==(other)
      name == other.name
    end

    def self.all
      conn.smembers('topics').map do |n|
        p = conn.hget("topic/#{n}", 'publisher')
        new(name: n, publisher: p)
      end
    end

    def marshal_dump
      [@name, @publisher]
    end

    def marshal_load(argv)
      initialize(name: argv[0], publisher: argv[1])
    end

    def self.find(name)
      new(name: name, publisher: nil)
    end

    extend Forwardable
    delegate %i(push peek pop length) => :_fifo

    private

    def _fifo
      @_fifo ||= Fifo.new("topic-#{@name}")
    end

    def _key
      @_key ||= "topic/#{@name}"
    end

    class Name < String
      def initialize(str)
        raise ArgumentError unless str.kind_of?(String)
        raise ArgumentError unless str =~ /[a-z_]{1,32}/
        super
      end
    end

    Publisher = Class.new(User)
  end
end
