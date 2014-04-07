require 'routemaster/mixins'
require 'logger'

module Routemaster::Mixins::Log

  def _log
    @@_logger ||= begin
      file_path = ENV['ROUTEMASTER_LOG_FILE']
      file = file_path ? File.open(file_path, 'a') : $stdout
      level = Logger.const_get(ENV.fetch('ROUTEMASTER_LOG_LEVEL', 'INFO'))
      Logger.new(file).tap do |logger|
        logger.level     = level 
        logger.formatter = method(:_formatter)
      end
    end
  end

  private

  TIMESTAMP_FORMAT = '%F %T.%L'

  def _formatter(severity, datetime, progname, message)
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
    ENV['RACK_ENV'] !~ /staging|production/
  end
end
