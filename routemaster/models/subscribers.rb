require 'routemaster/models'
require 'routemaster/mixins/connection'
require 'routemaster/mixins/assert'

module Routemaster::Models
  class Subscribers
    include Routemaster::Mixins::Connection
    include Routemaster::Mixins::Assert

    def initialize(topic)
      @topic = topic
    end

    def add(user)
      _assert user.kind_of?(User)
      conn.sadd(_key, user)
    end

    def to_a
      conn.smembers(_key)
    end

    private

    def _key
      @_key ||= "subscribers/#{@topic.name}"
    end
  end
end
