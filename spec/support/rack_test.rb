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

