require 'routemaster/models'
require 'routemaster/models/bunny_connection'
require 'delegate'
require 'bunny'

module Routemaster
  module Models
    class BunnyChannel < SimpleDelegator
      def initialize
        super BunnyConnection.instance.create_channel
      end
    end
  end
end
