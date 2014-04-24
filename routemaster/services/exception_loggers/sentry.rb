require 'singleton'
require 'routemaster/services'
require 'raven'

module Routemaster::Services::ExceptionLoggers
  class Sentry
    include Singleton

    def self.process(e, env = ENV['RACK_ENV'])
      if ENV['EXCEPTION_SERVICE_URL']
        evt = Raven::Event.capture_exception(e)
        Raven.send(evt) if evt
      end
    end

  end
end
