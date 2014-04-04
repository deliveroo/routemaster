require 'routemaster/models'
require 'routemaster/models/fifo'
require 'singleton'

module Routemaster::Models
  class Messages < Fifo
    include Singleton

    def initialize
      super('messages')
    end
  end
end
