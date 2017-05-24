require 'routemaster/mixins'
require 'routemaster/services/logger'

module Routemaster
  module Mixins
    module Log

      protected

      def _log
        @@_logger ||= Services::Logger.instance
      end

      def _log_exception(e)
        _log.warn { "#{e.class.name} (#{e.message})" }
        _log.debug { _smart_backtrace(e).join("\n\t") }
      end

      def _log_context(string)
        _log.context = string
      end

      private

      # show the top of the batcktrace until out own code, then only our own
      # code
      def _smart_backtrace(e)
        prefix = File.expand_path('../../..', __FILE__)
        seen_own = false
        e.backtrace.select do |line|
          matches = line.start_with?(prefix)
          seen_own = true if matches
          matches || !seen_own
        end
      end
    end
  end
end
