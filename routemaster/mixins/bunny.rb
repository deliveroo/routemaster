require 'routemaster/mixins'
require 'bunny'

module Routemaster::Mixins::Bunny
  def self.included(by)
    by.extend(self)
    by.send(:protected, :bunny)
  end

  def bunny
    @@_bunny ||= Bunny.new(ENV['ROUTEMASTER_AMQP_URL']).start.create_channel
  end

  def _bunny_disconnect
    @@_bunny = nil
  end

  def _bunny_name(string)
    "routemaster.#{ENV.fetch('RACK_ENV', 'development')}.#{string}"
  end
end
