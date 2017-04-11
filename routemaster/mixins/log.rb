require 'routemaster/mixins'
require 'logger'

module Routemaster
  module Mixins
    module Log

      protected

      def _log
        @@_logger ||= begin
          file_path = ENV['ROUTEMASTER_LOG_FILE']
          file = (file_path && File.exist?(file_path)) ? File.open(file_path, 'a') : $stderr

          instance = Logger.new(file).tap do |logger|
            logger.level     = _log_level_constant
            logger.formatter = method(:_formatter)
          end

          unless _log_level_valid?
            instance.warn("log level #{_log_level} is invalid, defaulting to INFO")
          end

          instance
        end
      end

      def _log_exception(e)
        _log.warn { "#{e.class.name} (#{e.message})" }
        _log.debug { _smart_backtrace(e).join("\n\t") }
      end

      def _log_context(string)
        Thread.current[:_log_context] = string
      end

      private

      TIMESTAMP_FORMAT = '%F %T.%L'

      def _formatter(severity, datetime, _progname, message)
        _format % {
          timestamp: datetime.utc.strftime(TIMESTAMP_FORMAT),
          level:     severity,
          message:   message,
          context:   Thread.current[:_log_context] || 'main',
        }
      end

      def _format
        @@_format ||= begin
          # In "deployed" environments (normally running Foreman), timestamps are
          # already added by the wrapper.
          _show_timestamp? ?
            "[%<timestamp>s] %<level>s: [%<context>s] %<message>s\n" :
            "%<level>s: [%<context>s] %<message>s\n"
        end
      end

      def _show_timestamp?
        ENV.fetch('RACK_ENV', 'development') !~ /staging|production/
      end

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

      def _log_level_constant
        if _log_level_valid?
          Logger.const_get(_log_level)
        else
          Logger::INFO
        end
      end

      def _log_level_valid?
        _log_levels.include?(_log_level)
      end

      def _log_level
        @@_log_level ||= ENV.fetch('ROUTEMASTER_LOG_LEVEL', 'INFO')
      end

      def _log_levels
        Logger::Severity.constants.map(&:to_s)
      end
    end
  end
end
