require 'rack/test'

# Makes Rack::Test think we always use SSL
class Rack::Test::Session
  def default_env
    { "rack.test" => true, "REMOTE_ADDR" => '127.0.0.1', 'HTTPS' => 'on' }.merge(headers_for_env)
  end
end

RSpec.configure do |conf|
  conf.include Rack::Test::Methods, type: :controller
end

class AuthenticatedApp
  def initialize(app, uid:)
    @uid = uid
    @app = app
  end

  def call(env)
    env['REMOTE_USER'] = @uid
    @app.call(env)
  end
end

