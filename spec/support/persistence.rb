require 'routemaster/mixins/redis'
require 'routemaster/mixins/bunny'
require 'singleton'
require 'faraday'
require 'rspec'
require 'uri'

class RedisCleaner
  include Singleton
  include Routemaster::Mixins::Redis

  def clean!
    _redis.flushdb
  end
end

class BunnyCleaner
  include Singleton
  include Routemaster::Mixins::Bunny

  def clean!
    Routemaster::Models::BunnyChannel.instance.disconnect

    _allowing_requests do
      vhost = URI.parse(ENV['ROUTEMASTER_AMQP_URL']).path

      # delete vhost
      r = _conn.delete("/api/vhosts/#{vhost}")
      raise unless [404, 204].include?(r.status)

      # create vhost
      r = _conn.put("/api/vhosts/#{vhost}") do |c|
        c.headers['Content-Type'] = 'application/json'
      end
      raise unless r.status == 204

      # set permissions
      r = _conn.put("/api/permissions/#{vhost}/guest") do |c|
        c.headers['Content-Type'] = 'application/json'
        c.body = '{"configure":".*","write":".*","read":".*"}'
      end
      raise unless r.status == 204
    end
  end

  private

  def _allowing_requests
    WebMock.disable! if defined?(WebMock)
    yield
    WebMock.enable! if defined?(WebMock)
  end

  def _conn
    @_conn ||= Faraday.new('http://guest:guest@localhost:15672')
  end
end

RSpec.configure do |config|
  config.before(:each) { RedisCleaner.instance.clean! }
  config.before(:each) { BunnyCleaner.instance.clean! }
  config.after(:suite) { WebMock.disable! }
end
