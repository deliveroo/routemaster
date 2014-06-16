require 'thread'
require 'routemaster/mixins/log'

class SafeThread
  include Routemaster::Mixins::Log

  def initialize(&block)
    @thread = Thread.new do
      Thread.abort_on_exception = true
      begin
        block.call
      rescue Exception => e
        _log_exception(e)
        raise
      end
    end
  end

  def respond_to?(method)
    @thread.respond_to?(method)
  end

  def method_missing(method, *args, &block)
    @thread.public_send(method, *args, &block)
  end
end
