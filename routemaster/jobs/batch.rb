require 'routemaster/jobs'
require 'routemaster/models/batch'
require 'routemaster/services/deliver'
require 'routemaster/mixins/log'

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

        events = batch.data.
          tap { |d| return self if d.empty? }. # batch has been deleted
          map { |d| Services::Codec.new.load(d) }.
          select { |msg| msg.kind_of?(Models::Event) }

        begin
          @delivery.call(batch.subscriber, events)
          batch.delete
        rescue Services::Deliver::CantDeliver => e
          _log_exception(e)
          attempts = batch.fail
          raise Models::Queue::Retry, _backoff(attempts)
        end
        self
      end

      private
      
      def _backoff(attempts)
        backoff = 1_000 * 2 ** [attempts-1, _backoff_limit].min
        backoff + rand(backoff)
      end

      def _backoff_limit
        @@_backoff_limit ||= Integer(ENV.fetch('ROUTEMASTER_BACKOFF_LIMIT'))
      end
    end
  end
end
