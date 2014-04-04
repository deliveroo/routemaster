require 'routemaster'
require 'routemaster/models/messages'

module Routemaster
  Message = Struct.new(:name, :payload)

  # Convenience module method to push a message to the service-wide queue
  def self.notify(message, payload)
    Models::Messages.instance.push Message.new(message, payload)
  end
end
