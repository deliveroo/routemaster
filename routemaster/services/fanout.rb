require 'routemaster/services'

class Routemaster::Services::Fanout
  def initialize(topic)
    @topic = topic
  end

  # dump implementation: pop from the topic, push to each queue
  # TODO: do this atomically with a Lua script
  def run
    event = @topic.pop
    return if event.nil?

    @topic.subscribers.each do |queue|
      queue.push(event)
    end
  end
end
