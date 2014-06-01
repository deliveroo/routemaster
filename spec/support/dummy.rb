require 'routemaster'
require 'routemaster/services'

module Routemaster::Services::ExceptionLoggers
  class Dummy
    include Singleton

    def process(e, env = ENV['RACK_ENV'])
      true
    end
  end
end
