require 'routemaster/models/base'
require 'routemaster/errors'

Routemaster::Errors::TopicClaimed = Class.new(Exception)

class Routemaster::Models::Topic < Routemaster::Models::Base

  def initialize(name:, publisher:)
    @name = Name.new(name)
    @publisher = Publisher.new(publisher)

    return if conn.hsetnx(_key, 'publisher', publisher)
    raise Routemaster::Errors::TopicClaimed unless
      conn.hget(_key, 'publisher') == @publisher
  end

  private

  def _key
    @_key ||= 'channels/#{@name}'
  end

  class Name < String
    def new(str)
      raise ArgumentError unless str.kind_of?(String)
      raise ArgumentError unless str =~ /[a-z_]{1,32}/
      super
    end
  end

  class Publisher < String
    def new(str)
      raise ArgumentError unless str.kind_of?(String)
      raise ArgumentError unless str =~ /[a-z0-9:_-]{1,64}/
      super
    end
  end
end
