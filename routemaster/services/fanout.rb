require 'routemaster/services'
require 'routemaster/notify'

class Routemaster::Services::Fanout
  def initialize(topic)
    @topic = topic
  end

  # dump implementation: pop from the topic, push to each subscription
  # TODO: do this atomically with a Lua script
  def run
    sent_event = false
    while event = @topic.pop
      sent_event = true
      @topic.subscribers.each { |s| s.push(event) }
    end

    if sent_event
      @topic.subscribers.each { |s| Routemaster.notify('subscription', s) }
    end
  end
end
