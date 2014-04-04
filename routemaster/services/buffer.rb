require 'routemaster/services'
require 'routemaster/models/fifo'

# Manage delivery buffer per subscription
class Routemaster::Services::Buffer
  def initialize(subscription)
    @subscription = subscription
    @buffer = subscription.buffer
  end

  def run
    # fill the buffer
    while @buffer.length < @subscription.max_events && @subscription.length > 0
      # TODO: use RPOPLPUSH to avoid the round-trip and avoid a breaking point
      event = @subscription.pop
      break if event.nil?
      @buffer.push(event)
    end
    
    # ping for delivery if buffer full or time elapsed 
  end

end

