require 'routemaster/services'
require 'routemaster/services/thread'
require 'routemaster/mixins/log'

module Routemaster
  module Services
    # Monitors a group of Thread.
    # If any thread ends with an error, ask all other threads to stop.
    class ThreadGroup
      include Mixins::Log

      def initialize
        @errq = Queue.new
        @threads = []
        ::Thread.new(&method(:_error_watcher))
      end

      def add(callable, name:)
        _log.info { "thread_group: adding #{name}" }
        @threads << Thread.new(callable, name: name, errq: @errq)
      end

      def stop
        return self unless @threads.any?
        _log.info { "thread_group: stopping" }
        @threads.each(&:stop)
        @errq.close
        self
      end

      def wait
        return self unless @threads.any?
        _log.info { "thread_group: waiting" }
        @threads.each(&:wait)
        @thread = []
        _log.info { "thread_group: all threads finished" }
        self
      end

      private 

      def _error_watcher
        while errored_thread = @errq.pop
          _log.warn { "thread_group: #{errored_thread.name} errored, stopping others" }
          stop
        end
      end
    end
  end
end

