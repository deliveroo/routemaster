require 'routemaster'
require 'singleton'

module Routemaster
  def self.connection
    @connection ||= Redis.new(ENV['ROUTEMASTER_REDIS_URL']) 
  end
end

