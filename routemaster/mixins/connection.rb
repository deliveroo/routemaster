require 'routemaster/mixins'
require 'redis'
require 'redis/connection/hiredis'

module Routemaster::Mixins::Connection
  def self.included(by)
    by.extend(self)
    by.send(:protected, :conn)
  end

  def conn
    @@_connection ||= Redis.new(url: ENV['ROUTEMASTER_REDIS_URL'])
  end
end
