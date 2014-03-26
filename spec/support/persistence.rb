
require 'routemaster/models/base'
class RedisCleaner < Routemaster::Models::Base
  def clean!
    conn.flushdb
  end
end

RSpec.configure do |config|
  config.after(:each) { RedisCleaner.new.clean! }
end
