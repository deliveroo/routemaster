require 'routemaster/models/messages'
require 'routemaster/services'
require 'routemaster/mixins/assert'

# require the classes we may need to deserialize
require 'routemaster/models/topic'
require 'routemaster/models/subscription'

# require the services we will perform
require 'routemaster/services/fanout'
require 'routemaster/services/buffer'
require 'routemaster/services/deliver'

module Routemaster::Services
  class Watch
    def initialize
      @messages = Routemaster::Models::Messages.instance
    end

    def run
      m = @messages.block_pop
      return if m.nil?

      case m.name
      when 'topic'        then Fanout.new(m.payload).run
      when 'subscription' then Buffer.new(m.payload).run
      when 'buffer'       then Deliver.new(m.payload).run
      else
        raise 'bad message received'
      end
    end
  end
end
