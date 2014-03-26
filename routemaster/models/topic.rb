require 'routemaster/models'
require 'routemaster/errors'

Routemaster::Errors::TopicClaimed = Class.new(Exception)

class Routemaster::Models::Topic

  def initialize(name:, publisher:)
    @name = Name.new(name)
    @publisher = Publisher.new(publisher)
  end

  private

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
