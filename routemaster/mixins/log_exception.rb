require 'routemaster/mixins'
require "routemaster/services/exception_loggers/#{ENV['EXCEPTION_SERVICE']}"

module Routemaster::Mixins::LogException

  protected

  def with_exception_logging(&block)
    yield
  rescue => e
    # send the exception message to your choice of service!
    if service = ENV['EXCEPTION_SERVICE'].camelize
      Routemaster::Services::ExceptionLoggers.const_get(service).process(e)
    else
      _log_exception(e)
    end
    raise
  end

end
