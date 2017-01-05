require 'routemaster/models'
require 'routemaster/mixins/redis'
require 'msgpack'
require 'core_ext/string'

module Routemaster
  module Models
    # Something to be run asynchronously.
    class Job
      attr_reader :name, :args, :run_at

      def initialize(name:, args:[], run_at:nil, data:nil)
        @name   = name
        @args   = Array(args)
        @run_at = run_at
        @data   = data
      end

      def perform
        require "routemaster/jobs/#{@name}"
        Routemaster::Jobs.const_get(@name.camelize).new.call(*@args)
      end

      def dump
        @data ||= MessagePack.dump([@name, @args])
      end

      def ==(other)
        other.kind_of?(Job) && @name == other.name && @args == other.args
      end

      def inspect
        "<Job:#{@name} argv=#{@args.inspect}>"
      end

      module ClassMethods
        def load(data, **options)
          name, args = MessagePack.load(data)
          new(options.merge(name: name, args: args, data: data))
        end
      end
      extend ClassMethods
    end
  end
end

