require 'routemaster/services'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/log_exception'

class Routemaster::Services::Pulse
  include Routemaster::Mixins::Redis
  include Routemaster::Mixins::LogException

  def run
    _redis_alive?
  end

  private

  def _redis_alive?
    _redis.ping
    true
  rescue Redis::CannotConnectError => e
    deliver_exception(e)
    false
  end
end
