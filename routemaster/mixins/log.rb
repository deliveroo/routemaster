require 'routemaster/mixins'
require 'logger'

module Routemaster::Mixins::Log

  protected

  def _log
    @@_logger ||= begin
      file_path = ENV['ROUTEMASTER_LOG_FILE']
      file = (file_path && File.exist?(file_path)) ? File.open(file_path, 'a') : $stderr
      level = Logger.const_get(ENV.fetch('ROUTEMASTER_LOG_LEVEL', 'INFO'))
      Logger.new(file).tap do |logger|
        logger.level     = level
        logger.formatter = method(:_formatter)
      end
    end
  end

  def _log_exception(e)
    _log.warn { "#{e.class.name} (#{e.message})" }
    _log.debug { e.backtrace.join("\n") }
  end

  private

  TIMESTAMP_FORMAT = '%F %T.%L'

  def _formatter(severity, datetime, progname, message)
    # In "deployed" environments (normally running Foreman), timestamps are
    # already added by the wrapper.
    if _show_timestamp?
      "[%s] %s: %s\n" % [
        datetime.utc.strftime(TIMESTAMP_FORMAT),
        severity,
        message
      ]
    else
      "%s: %s\n" % [
        severity, message
      ]
    end
  end

  def _show_timestamp?
    ENV.fetch('RACK_ENV', 'development') !~ /staging|production/
  end
end
