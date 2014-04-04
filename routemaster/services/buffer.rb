require 'routemaster/services'
require 'routemaster/models/fifo'

# Manage delivery buffer per queue
class Routemaster::Services::Buffer
  def initialize(queue)
    @queue = queue
    @buffer = queue.buffer
  end

  def run
    # fill the buffer
    while @buffer.length < @queue.max_events && @queue.length > 0
      # TODO: use RPOPLPUSH to avoid the round-trip and avoid a breaking point
      event = @queue.pop
      break if event.nil?
      @buffer.push(event)
    end
    
    # ping for delivery if buffer full or time elapsed 
  end

end

