require 'routemaster/jobs'
require 'routemaster/models/batch'
require 'routemaster/services/deliver'
require 'routemaster/services/throttle'
require 'routemaster/mixins/log'
require 'routemaster/exceptions'

module Routemaster
  module Jobs
    class Batch
      include Mixins::Log

      def initialize(delivery: Services::Deliver)
        @delivery = delivery
      end

      def call(uid)
        batch = Models::Batch.new(uid: uid)

        # prevents further ingestion in this batch (idempotent)
        batch.promote

        # handle unsubscription, autodrop
        unless batch.valid?
          batch.delete
          return self
        end
        # nb. batch.valid? has memoised #data and #subscriber,
        # so deletions (autodropping) after this point won't affect us

        events = batch.data.
          map { |d| Services::Codec.new.load(d) }.
          select { |msg| msg.kind_of?(Models::Event) }

        begin
          @delivery.call(batch.subscriber, events)
          batch.delete
        rescue Exceptions::DeliveryFailure => e
          _log_exception(e)
          raise Models::Queue::Retry, e.delay
        end
        self
      end
    end
  end
end
