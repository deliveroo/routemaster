require 'routemaster/services'
require 'routemaster/mixins/connection'

class Routemaster::Services::Pulse
  include Routemaster::Mixins::Connection

  def run
    conn.ping
    true
  rescue Redis::CannotConnectError
    false
  end
end
