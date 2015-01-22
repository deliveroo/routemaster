require 'routemaster/models'
require 'routemaster/models/message'
require 'routemaster/mixins/log'
require 'routemaster/mixins/bunny'
require 'routemaster/mixins/assert'

module Routemaster
  module Models
    # Takes a Subscription and yields Messages,
    # thus abstracting the Bunny/RabbitMQ API.
    class Consumer
      include Routemaster::Mixins::Log

      def initialize(subscription)
        @subscription = subscription
      end


      def pop
        info, props, payload = @subscription.queue.pop(manual_ack: true)
        return if info.nil? && props.nil? && payload.nil?
        Message.new(info, props, payload)
      end

      def to_s
        "subscriber:#{@subscription.subscriber} id:0x#{object_id.to_s(16)}"
      end

      def inspect
        "<#{self.class.name} #{self}>"
      end
    end
  end
end

