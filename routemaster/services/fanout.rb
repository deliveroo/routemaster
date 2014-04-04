require 'routemaster/services'
require 'routemaster/notify'

class Routemaster::Services::Fanout
  def initialize(topic)
    @topic = topic
  end

  # dump implementation: pop from the topic, push to each subscription
  # TODO: do this atomically with a Lua script
  def run
    event = @topic.pop
    return if event.nil?

    @topic.subscribers.each do |subscription|
      subscription.push(event)
      Routemaster.notify('subscription', subscription)
    end
  end
end
