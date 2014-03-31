
require 'routemaster/mixins/connection'
require 'singleton'

class RedisCleaner
  include Singleton
  include Routemaster::Mixins::Connection

  def clean!
    conn.flushdb
  end
end

RSpec.configure do |config|
  config.before(:each) { RedisCleaner.instance.clean! }
end
