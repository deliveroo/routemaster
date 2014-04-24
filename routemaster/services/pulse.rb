require 'routemaster/services'
require 'routemaster/mixins/redis'
require 'routemaster/mixins/log_exception'

class Routemaster::Services::Pulse
  include Routemaster::Mixins::Redis
  include Routemaster::Mixins::LogException

  def run
    with_exception_logging do
      _redis.ping
      true
    end
  rescue Redis::CannotConnectError
    false
  end
end
