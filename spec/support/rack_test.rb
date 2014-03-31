ENV['RACK_ENV'] = 'test'

require 'rspec'
require 'rack/test'

RSpec.configure do |conf|
  conf.include Rack::Test::Methods
end

class AuthenticatedApp
  def initialize(app, uid: uid)
    @uid = uid
    @app = app
  end

  def call(env)
    env['REMOTE_USER'] = @uid
    @app.call(env)
  end
end

