require 'routemaster/services'
require 'routemaster/mixins/log'
require 'routemaster/mixins/log_exception'

module Routemaster
  module Services
    # Abstracts out repeatedly calling `callable` on a thread.
    # On exceptions, enqueues itself to `errq`
    class Thread
      include Mixins::Log
      include Mixins::LogException

      attr_reader :name
      
      def initialize(callable, name:, errq:)
        @callable = callable
        @name     = name
        @errq     = errq
        @running  = true
        @thread   = ::Thread.new(&method(:_run))
        @thread.abort_on_exception = true
      end

      def stop
        _log.info { "#{name}: stopping" }
        @running = false
        self
      end

      def wait
        return self unless @thread
        @thread.join
        @thread = nil
        _log.info { "#{name}: terminated" }
        self
      end

      private

      def _run
        _log.info { "#{name}: starting" }
        while @running
          @callable.call
          _log.info { "#{name}: callable returning" }
        end
        _log.info { "#{name}: stopped" }
      rescue StandardError => e
        _log.warn { "#{name}: aborting on #{e.class.name}, #{e.message}" }
        _log_exception(e)
        deliver_exception(e)
        @errq.push self
        @running = false
      end
    end
  end
end
