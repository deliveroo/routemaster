require 'routemaster/models'
require 'singleton'
require 'redis'
require 'redis/connection/hiredis'

class Routemaster::Models::Base

  protected

  module Connection
    def conn
      @@_connection ||= Redis.new(url: ENV['ROUTEMASTER_REDIS_URL'])
    end
  end
  include Connection
  extend Connection
end
