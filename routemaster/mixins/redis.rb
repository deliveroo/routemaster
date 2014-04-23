require 'routemaster/mixins'
require 'redis'
require 'redis/connection/hiredis'

module Routemaster::Mixins::Redis
  def self.included(by)
    by.extend(self)
    by.send(:protected, :_redis)
  end

  def _redis
    @@_redis ||= Redis.new(url: ENV['ROUTEMASTER_REDIS_URL'])
  end
end
