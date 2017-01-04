require 'routemaster/jobs'
require 'routemaster/models/database'
require 'routemaster/models/subscriber'
require 'routemaster/mixins/log'

module Routemaster
  module Jobs
    # Autodrop messages from queues until the database is empty enough.
    #
    # Naive algorithm for now: just drop the oldest messages from all queues
    # until we're below the low-water mark.
    class Autodrop
      include Mixins::Log

      BATCH_SIZE = 100

      def initialize(batch_size: BATCH_SIZE, database: Models::Database.instance)
        @database   = database
        @batch_size = batch_size
      end

      def call
        return unless @database.too_full?
        n_messages = n_batches = 0

        # loop through queues, removing messages
        until @database.empty_enough?
          Models::Batch.all.take(@batch_size).each do |batch|
            n_messages += batch.length
            n_batches += 1
            batch.delete
          end
        end
        _log.info { "auto-drop: removed #{n_messages} messages in #{n_batches} batches" }
        n_batches
      end
    end
  end
end

