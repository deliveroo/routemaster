require 'routemaster/models'
require 'singleton'
require 'redis'
require 'redis/connection/hiredis'

class Routemaster::Models::Base

  protected

  def conn
    @@_connection ||= Redis.new(url: ENV['ROUTEMASTER_REDIS_URL'])
  end
end
