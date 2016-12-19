require 'routemaster/services'
require 'routemaster/models/database'
require 'routemaster/models/subscriber'
require 'routemaster/mixins/log'
require 'ostruct'

module Routemaster
  module Services
    # Autodrop messages from queues until the database is empty enough.
    #
    # Naive algorithm for now: just drop the oldest messages from all queues
    # until we're below the low-water mark.
    class Autodrop
      include Mixins::Log

      BATCH_SIZE = 100

      def initialize
        @database = Models::Database.instance
      end

      def call
        _log.info { 'auto-drop: starting' }
        return false unless @database.too_full?
        messages_removed = 0
        # queues = Models::Subscriber.map(&:queue)

        # loop through queues, removing messages
        until @database.empty_enough?
          # queues.sort_by!(&:staleness)
          # messages_removed += queues.last.drop(BATCH_SIZE)
        end
        _log.info { "auto-drop: removed #{messages_removed} messages" }
        messages_removed
      end
    end
  end
end

