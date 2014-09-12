require 'singleton'
require 'routemaster/services'
require 'routemaster/mixins/log'

module Routemaster::Services::MetricsCollectors
  class Print
    include Routemaster::Mixins::Log
    include Singleton

    def perform(name, value, tags, output = nil)
      _log.info("#{name}:#{value} (#{tags.join(",")})")
    end

  end
end
