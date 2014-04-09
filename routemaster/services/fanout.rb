require 'routemaster/services'
require 'routemaster/notify'
require 'routemaster/mixins/log'

class Routemaster::Services::Fanout
  include Routemaster::Mixins::Log

  def initialize(topic)
    @topic = topic
  end

  # dump implementation: pop from the topic, push to each subscription
  # TODO: do this atomically with a Lua script
  def run
    _log.debug { "starting fanout for '#{@topic.name}'" }

    event_counter = 0
    while event = @topic.pop
      event_counter += 1
      @topic.subscribers.each { |s| s.push(event) }
    end

    if event_counter > 0
      @topic.subscribers.each { |s| Routemaster.notify('subscription', s) }
      _log_count(event_counter)
    end
  end

  private 

  def _log_count(count)
    _log.debug do
      if !@topic.subscribers.any?
        "dispatched #{count} events, no subscribers"
      else
        names = @topic.subscribers.map(&:subscriber).join("', '")
        "dispached #{count} events from '#{@topic.name}' to '#{names}'"
      end
    end
  end
end
