require 'singleton'
require 'routemaster/services'
require 'routemaster/mixins/log'

module Routemaster::Services::ExceptionLoggers
  class Print
    include Routemaster::Mixins::Log
    include Singleton

    def process(e, env = ENV['RACK_ENV'])
      _log_exception(e)
    end

  end
end
