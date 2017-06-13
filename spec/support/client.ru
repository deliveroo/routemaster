require 'routemaster/receiver'
require 'json'

class Handler
  def on_events(batch)
    $stderr.puts "received batch of #{batch.length} events"
    batch.each do |event|
      $stderr.puts "received #{event['url']}, #{event['type']}, #{event['topic']}"
      $stderr.puts "payload: #{event['data'].to_json}" if event['data']
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
  uuid:    "1c44d34f-6e53-4a4f-9756-4bb8480a7a19",
  handler: Handler.new
}

run App
