require 'routemaster/services'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/bunny'
require 'routemaster/mixins/log_exception'

class Routemaster::Services::Pulse
  include Routemaster::Mixins::Redis
  include Routemaster::Mixins::Bunny
  include Routemaster::Mixins::LogException

  def run
    _redis_alive? && _bunny_alive?
  end

  private

  def _redis_alive?
    _redis.ping
    true
  rescue Redis::CannotConnectError
    false
  end

  def _bunny_alive?
    bunny.connection.connected?
  rescue Bunny::TCPConnectionFailed
    false
  end
end
