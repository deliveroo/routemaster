module Routemaster
  module Exceptions

    # Abstract class.
    #
    # Raised when delivering batches (events) to suscribers fails.
    # Common failure reasons:
    #   - HTTP error response (!= 20x) from the subscribers
    #   - Network and connection errors
    #   - Healthcheck throttling: a subscriber is marked as unhealthy
    #     and deliveries are halted and delayed.
    #
    # Attributes:
    #   - delay (numeric): a backoff time interval, expressed in ms.
    #
    #
    class DeliveryFailure < StandardError
      attr_reader :delay

      def initialize(message, delay)
        @delay = delay
        super(message)
      end
    end

    # Concrete class.
    #
    # Raised in case of HTTP error response or network error
    #
    class CantDeliver < DeliveryFailure
    end


    # Concrete class.
    #
    # Raised when delivery attempts are halted and are meant to
    # be re-sheduled.
    #
    class EarlyThrottle < DeliveryFailure
      def initialize(delay, subscriber_name)
        message = "Throttling batch deliveries to the '#{subscriber_name}' subscriber."
        super(message, delay)
      end
    end
  end
end
