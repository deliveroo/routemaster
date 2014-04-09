require 'routemaster/services'
require 'routemaster/notify'
require 'routemaster/models/fifo'
require 'routemaster/mixins/log'

# Manage delivery buffer per subscription
class Routemaster::Services::Buffer
  include Routemaster::Mixins::Log

  def initialize(subscription)
    @subscription = subscription
    @buffer = subscription.buffer
  end

  def run
    _log.debug { "starting buffering for '#{@subscription.subscriber}'" }
    event_counter = 0

    # fill the buffer
    while @buffer.length < @subscription.max_events && @subscription.length > 0
      # TODO: use RPOPLPUSH to avoid the round-trip and avoid a breaking point
      event = @subscription.pop
      break if event.nil?
      @buffer.push(event)
      event_counter += 1
    end
    
    # ping for delivery if buffer full or time elapsed
    if @subscription.stale? || @buffer.length >= @subscription.max_events
      Routemaster.notify('buffer', @subscription)
    end

    if event_counter > 0
      _log.debug { "buffered #{event_counter} events for '#{@subscription.subscriber}'" }
    end
  end
end

