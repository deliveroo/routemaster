require 'routemaster/receiver'

class Handler
  def on_events(batch)
    batch.each do |event|
      $stderr.puts "received #{event['url']}, #{event['type']}, #{event['topic']}"
      $stderr.flush
    end
  end
end

class App
  def call(env)
    [500, {}, []]
  end
end

use Routemaster::Receiver, {
  path:    '/events',
  uuid:    'demo',
  handler: Handler.new
}

run App
