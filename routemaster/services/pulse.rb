require 'routemaster/services'
require 'routemaster/mixins/redis'

class Routemaster::Services::Pulse
  include Routemaster::Mixins::Redis

  def run
    _redis.ping
    true
  rescue Redis::CannotConnectError
    false
  end
end
