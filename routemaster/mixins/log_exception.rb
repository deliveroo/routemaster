require 'routemaster/mixins'

module Routemaster::Mixins::LogException

  protected

  def with_exception_logging(&block)
    p "Logging the Exception"
    yield
  rescue => e
    # send the exception message to your choice of service!
    if service = ENV['EXCEPTION_SERVICE']
      Routemaster::Services::ExceptionLoggers.const_get(service).process(e)
    else
      _log_exception(e)
    end
    raise
  end

end
