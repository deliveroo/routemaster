require 'routemaster/services'
require 'routemaster/models/fifo'
require 'routemaster/mixins/log'
require 'faraday'
require 'faraday_middleware'

# Manage delivery buffer and emitting the HTTP delivery
class Routemaster::Services::Deliver
  include Routemaster::Mixins::Log

  def initialize(subscription)
    @subscription  = subscription
    @buffer = subscription.buffer
  end

  def run
    _log.debug { "starting delivery to '#{@subscription.subscriber}'" }

    # check if buffer full or time elapsed
    return unless _should_deliver?

    # TODO: lock the buffer for writing
    # also avoid clearing it until the acknowledgment from the callback

    # assemble data
    data = []
    events = []
    while event = @buffer.pop
      events << event
      data << {
        topic: event.topic,
        type:  event.type,
        url:   event.url,
        t:     event.timestamp
      }
    end

    # send data
    response = conn.post do |post|
      post.body = data 
    end
    if response.success?
      _log.debug { "delivered #{events.length} events to '#{@subscription.subscriber}'" } 
      return
    else
      _log.warn { "failed to deliver #{events.length} events to '#{@subscription.subscriber}'" }
    end
    
    # put events back in case of failure
    events.each { |e| @buffer.push e }

    nil
  end

  private

  def _should_deliver?
    return true  if @subscription.stale?
    return false if @buffer.length == 0
    return true  if @buffer.length >= @subscription.max_events
    false
  end

  def conn
    @_conn ||= begin
      Faraday.new(@subscription.callback) { |c|
        c.request :json
        c.adapter Faraday.default_adapter
      }.tap { |c|
        c.basic_auth(@subscription.uuid, 'x')
      }
    end
  end
end
